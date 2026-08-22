defmodule ExperimentHub.RLSEnforcementTest do
  @moduledoc """
  Proves tenant isolation is enforced by Postgres itself, not merely by
  `ExperimentHub.Repo.prepare_query/3`.

  `ExperimentHub.RLSIntegrationTest` and `ExperimentHub.RepoTest`'s GUC
  lifecycle tests both run every query through `ExperimentHub.Repo`, whose
  role in this environment (see
  `.superpowers/fixes/elixir-correctness-report.md`) has either SUPERUSER
  or an explicit BYPASSRLS attribute -- both bypass row security
  unconditionally, `FORCE ROW LEVEL SECURITY` notwithstanding. Those tests
  therefore exercise `prepare_query/3`'s own Ecto-level `WHERE tenant_id =
  ...` injection; they would pass or fail identically if every RLS policy
  in the migrations were dropped. They do not prove the database enforces
  anything.

  This module runs raw SQL (`Postgrex.query!/3`, on a connection
  `ExperimentHub.Repo` never touches) as a role created here specifically
  without `SUPERUSER` and without `BYPASSRLS` (see
  `ExperimentHub.TestSupport.RLSProbe`), so `FORCE ROW LEVEL SECURITY`
  actually binds it, against two tenant-scoped tables:

    * `experiments` -- RLS enabled and policy created in migration
      `20260401000005`; `FORCE` added in `20260401000023`.
    * `feature_flags` -- RLS enabled in `20260401000019`, but the
      `tenant_isolation` policy itself (and `FORCE`) were only added in
      `20260401000023` -- the migration this task calls out by name.

  Because `Ecto.Adapters.SQL.Sandbox` confines a test's writes to an
  uncommitted transaction invisible to any other connection, this suite
  does not use `ExperimentHub.DataCase` -- it inserts and deletes real,
  committed fixture rows through a plain admin `Postgrex` connection (see
  `RLSProbe.start_admin_connection!/0`) so the separately-authenticated
  probe connection can actually see them.
  """

  use ExUnit.Case, async: false

  alias ExperimentHub.TestSupport.RLSProbe

  setup_all do
    admin = RLSProbe.start_admin_connection!()
    RLSProbe.ensure_probe_role!(admin, ["experiments", "feature_flags"])

    on_exit(fn -> GenServer.stop(admin) end)

    %{admin: admin}
  end

  setup %{admin: admin} do
    tenant_a = Ecto.UUID.generate()
    tenant_b = Ecto.UUID.generate()

    insert_tenant!(admin, tenant_a, "RLS Probe Tenant A")
    insert_tenant!(admin, tenant_b, "RLS Probe Tenant B")

    experiment_a_key = "rls-probe-exp-a-#{Ecto.UUID.generate()}"
    experiment_b_key = "rls-probe-exp-b-#{Ecto.UUID.generate()}"
    insert_experiment!(admin, Ecto.UUID.generate(), tenant_a, experiment_a_key)
    insert_experiment!(admin, Ecto.UUID.generate(), tenant_b, experiment_b_key)

    flag_a_key = "rls-probe-flag-a-#{Ecto.UUID.generate()}"
    flag_b_key = "rls-probe-flag-b-#{Ecto.UUID.generate()}"
    insert_feature_flag!(admin, Ecto.UUID.generate(), tenant_a, flag_a_key)
    insert_feature_flag!(admin, Ecto.UUID.generate(), tenant_b, flag_b_key)

    on_exit(fn -> delete_fixtures!(admin, tenant_a, tenant_b) end)

    %{
      tenant_a: tenant_a,
      tenant_b: tenant_b,
      experiment_a_key: experiment_a_key,
      experiment_b_key: experiment_b_key,
      flag_a_key: flag_a_key,
      flag_b_key: flag_b_key
    }
  end

  describe "experiments (policy from 20260401000005, FORCE added in 20260401000023)" do
    test "a probe connection scoped to tenant A sees tenant A's experiment, not tenant B's",
         ctx do
      keys =
        RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
          %{rows: rows} = Postgrex.query!(conn, "SELECT key FROM experiments", [])
          Enum.map(rows, fn [key] -> key end)
        end)

      assert ctx.experiment_a_key in keys
      refute ctx.experiment_b_key in keys
    end

    test "a probe connection scoped to tenant B sees tenant B's experiment, not tenant A's",
         ctx do
      keys =
        RLSProbe.with_probe_connection(ctx.tenant_b, fn conn ->
          %{rows: rows} = Postgrex.query!(conn, "SELECT key FROM experiments", [])
          Enum.map(rows, fn [key] -> key end)
        end)

      assert ctx.experiment_b_key in keys
      refute ctx.experiment_a_key in keys
    end

    test "with no tenant context set at all, the probe connection resolves neither tenant's experiments",
         _ctx do
      # The tenant_isolation policy's `current_setting('app.current_tenant_id')`
      # has no `missing_ok` argument, so on a connection that never set the
      # GUC, Postgres raises evaluating the policy itself -- fail-closed,
      # not a silent, empty result that happens to look like "no access".
      assert_raise Postgrex.Error, ~r/unrecognized configuration parameter/, fn ->
        RLSProbe.with_probe_connection(nil, fn conn ->
          Postgrex.query!(conn, "SELECT key FROM experiments", [])
        end)
      end
    end
  end

  describe "feature_flags (tenant_isolation policy + FORCE both added in 20260401000023)" do
    test "a probe connection scoped to tenant A sees tenant A's flag, not tenant B's", ctx do
      keys =
        RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
          %{rows: rows} = Postgrex.query!(conn, "SELECT key FROM feature_flags", [])
          Enum.map(rows, fn [key] -> key end)
        end)

      assert ctx.flag_a_key in keys
      refute ctx.flag_b_key in keys
    end

    test "a probe connection scoped to tenant B sees tenant B's flag, not tenant A's", ctx do
      keys =
        RLSProbe.with_probe_connection(ctx.tenant_b, fn conn ->
          %{rows: rows} = Postgrex.query!(conn, "SELECT key FROM feature_flags", [])
          Enum.map(rows, fn [key] -> key end)
        end)

      assert ctx.flag_b_key in keys
      refute ctx.flag_a_key in keys
    end

    test "with no tenant context set at all, the probe connection resolves neither tenant's flags",
         _ctx do
      assert_raise Postgrex.Error, ~r/unrecognized configuration parameter/, fn ->
        RLSProbe.with_probe_connection(nil, fn conn ->
          Postgrex.query!(conn, "SELECT key FROM feature_flags", [])
        end)
      end
    end
  end

  defp insert_tenant!(admin, id, name) do
    Postgrex.query!(
      admin,
      """
      INSERT INTO tenants (id, name, slug, settings, inserted_at, updated_at)
      VALUES ($1, $2, $3, '{}'::jsonb, now(), now())
      """,
      [Ecto.UUID.dump!(id), name, "rls-probe-#{id}"]
    )
  end

  defp insert_experiment!(admin, id, tenant_id, key) do
    Postgrex.query!(
      admin,
      """
      INSERT INTO experiments (id, tenant_id, key, name, hypothesis, status, inserted_at, updated_at)
      VALUES ($1, $2, $3, $3, 'h', 'draft', now(), now())
      """,
      [Ecto.UUID.dump!(id), Ecto.UUID.dump!(tenant_id), key]
    )
  end

  defp insert_feature_flag!(admin, id, tenant_id, key) do
    Postgrex.query!(
      admin,
      """
      INSERT INTO feature_flags (id, tenant_id, key, name, status, inserted_at, updated_at)
      VALUES ($1, $2, $3, $3, 'disabled', now(), now())
      """,
      [Ecto.UUID.dump!(id), Ecto.UUID.dump!(tenant_id), key]
    )
  end

  defp delete_fixtures!(admin, tenant_a, tenant_b) do
    tenant_ids = [Ecto.UUID.dump!(tenant_a), Ecto.UUID.dump!(tenant_b)]
    Postgrex.query!(admin, "DELETE FROM feature_flags WHERE tenant_id = ANY($1)", [tenant_ids])
    Postgrex.query!(admin, "DELETE FROM experiments WHERE tenant_id = ANY($1)", [tenant_ids])
    Postgrex.query!(admin, "DELETE FROM tenants WHERE id = ANY($1)", [tenant_ids])
  end
end
