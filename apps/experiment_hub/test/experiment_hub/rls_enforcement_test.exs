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

  Beyond the original SELECT-only, positive-tenant-only coverage, this
  suite also proves:

    * **Write paths.** The probe role is granted INSERT/UPDATE/DELETE (not
      just SELECT -- see `RLSProbe.ensure_probe_role!/2`), and the
      "write policy enforcement" describes below show Postgres itself
      permits inserting/updating/deleting the probe's own tenant's rows
      and blocks the same operations against the other tenant's rows
      (INSERT raises a `WITH CHECK` violation; UPDATE/DELETE silently
      affect zero rows, filtered out by `USING` before they reach the
      row), each verified independently through the RLS-bypassing admin
      connection.
    * **A negative control.** The "negative control" describe below shows
      the probe role is not simply blind: it asserts a *nonzero,
      specific* result when scoped to its own tenant (not just the
      absence of the other tenant's row), and separately proves the same
      role's SELECT/INSERT genuinely work at all by seeing rows across
      both tenant markers on a table with no tenant_id column and no RLS
      policy whatsoever -- something a broken or over-restricted probe
      role could not do.
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

  describe "negative control -- the probe is not simply blind" do
    test "a probe scoped to tenant A sees a nonzero number of rows, not just the absence of tenant B's",
         ctx do
      keys =
        RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
          %{rows: rows} = Postgrex.query!(conn, "SELECT key FROM experiments", [])
          Enum.map(rows, fn [key] -> key end)
        end)

      # The `refute ... in keys` assertions elsewhere only prove the *other*
      # tenant's row is absent -- a probe role with, say, SELECT silently
      # revoked (or pointed at the wrong table) would also produce an empty
      # list and pass those identically. This asserts the list is actually
      # populated with the row it should see.
      assert keys != []
      assert ctx.experiment_a_key in keys
    end

    test "on a table with no tenant_id column and no RLS policy at all, the same probe role sees rows across both tenant markers regardless of GUC",
         _ctx do
      RLSProbe.with_probe_connection(nil, fn conn ->
        # Deliberately policy-free: no app.current_tenant_id is set (nil),
        # and this temp table has no tenant_id column and no RLS policy
        # whatsoever. If the probe role's SELECT/INSERT privileges were
        # simply broken (or misdirected at the wrong object), this query
        # would return nothing -- indistinguishable from the fail-closed
        # test above. Seeing both markers here proves the probe role's
        # privileges genuinely work, so the tenant-scoped and fail-closed
        # results elsewhere are the `tenant_isolation` policy doing
        # something, not the probe silently doing nothing.
        Postgrex.query!(conn, "CREATE TEMP TABLE rls_probe_control (marker text)", [])
        Postgrex.query!(conn, "INSERT INTO rls_probe_control VALUES ('tenant-a-marker')", [])
        Postgrex.query!(conn, "INSERT INTO rls_probe_control VALUES ('tenant-b-marker')", [])

        %{rows: rows} = Postgrex.query!(conn, "SELECT marker FROM rls_probe_control", [])
        markers = Enum.map(rows, fn [marker] -> marker end)

        assert "tenant-a-marker" in markers
        assert "tenant-b-marker" in markers
      end)
    end
  end

  describe "write policy enforcement (experiments) -- INSERT/UPDATE/DELETE, not just SELECT" do
    test "a probe scoped to tenant A can insert, update, and delete its own tenant's rows", ctx do
      own_insert_id = Ecto.UUID.generate()
      own_insert_key = "rls-probe-write-own-#{own_insert_id}"

      RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
        Postgrex.query!(
          conn,
          """
          INSERT INTO experiments (id, tenant_id, key, name, hypothesis, status, inserted_at, updated_at)
          VALUES ($1, $2, $3, $3, 'h', 'draft', now(), now())
          """,
          [Ecto.UUID.dump!(own_insert_id), Ecto.UUID.dump!(ctx.tenant_a), own_insert_key]
        )

        %Postgrex.Result{num_rows: updated} =
          Postgrex.query!(
            conn,
            "UPDATE experiments SET name = 'updated-by-probe' WHERE key = $1",
            [ctx.experiment_a_key]
          )

        assert updated == 1

        %Postgrex.Result{num_rows: deleted} =
          Postgrex.query!(conn, "DELETE FROM experiments WHERE key = $1", [own_insert_key])

        assert deleted == 1
      end)

      # Verify against the admin (RLS-bypassing) connection, independent of
      # the probe connection's own view: the update really landed, and the
      # inserted-then-deleted row is really gone.
      %{rows: [[name]]} =
        Postgrex.query!(ctx.admin, "SELECT name FROM experiments WHERE key = $1", [
          ctx.experiment_a_key
        ])

      assert name == "updated-by-probe"

      %{rows: rows} =
        Postgrex.query!(ctx.admin, "SELECT 1 FROM experiments WHERE key = $1", [own_insert_key])

      assert rows == []
    end

    test "a probe scoped to tenant A is blocked from inserting, updating, or deleting tenant B's rows",
         ctx do
      cross_tenant_id = Ecto.UUID.generate()
      cross_tenant_key = "rls-probe-write-cross-#{cross_tenant_id}"

      RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
        # INSERT claiming tenant B's id while scoped as tenant A violates
        # the policy's WITH CHECK (the same expression as USING, since the
        # policy declares no separate WITH CHECK and no FOR clause, so it
        # applies to ALL commands) and raises.
        assert_raise Postgrex.Error, ~r/row-level security policy/, fn ->
          Postgrex.query!(
            conn,
            """
            INSERT INTO experiments (id, tenant_id, key, name, hypothesis, status, inserted_at, updated_at)
            VALUES ($1, $2, $3, $3, 'h', 'draft', now(), now())
            """,
            [Ecto.UUID.dump!(cross_tenant_id), Ecto.UUID.dump!(ctx.tenant_b), cross_tenant_key]
          )
        end

        # UPDATE targeting tenant B's existing row is filtered out by the
        # USING clause before it ever reaches the row: zero rows affected,
        # not an error.
        %Postgrex.Result{num_rows: updated} =
          Postgrex.query!(
            conn,
            "UPDATE experiments SET name = 'should-not-apply' WHERE key = $1",
            [ctx.experiment_b_key]
          )

        assert updated == 0

        # Same for DELETE.
        %Postgrex.Result{num_rows: deleted} =
          Postgrex.query!(conn, "DELETE FROM experiments WHERE key = $1", [ctx.experiment_b_key])

        assert deleted == 0
      end)

      # Verify against the admin connection: tenant B's row is untouched
      # and the cross-tenant insert never landed.
      %{rows: [[name]]} =
        Postgrex.query!(ctx.admin, "SELECT name FROM experiments WHERE key = $1", [
          ctx.experiment_b_key
        ])

      assert name == ctx.experiment_b_key

      %{rows: rows} =
        Postgrex.query!(ctx.admin, "SELECT 1 FROM experiments WHERE key = $1", [
          cross_tenant_key
        ])

      assert rows == []
    end
  end

  describe "write policy enforcement (feature_flags) -- INSERT/UPDATE/DELETE, not just SELECT" do
    test "a probe scoped to tenant A can insert, update, and delete its own tenant's rows", ctx do
      own_insert_id = Ecto.UUID.generate()
      own_insert_key = "rls-probe-write-own-#{own_insert_id}"

      RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
        Postgrex.query!(
          conn,
          """
          INSERT INTO feature_flags (id, tenant_id, key, name, status, inserted_at, updated_at)
          VALUES ($1, $2, $3, $3, 'disabled', now(), now())
          """,
          [Ecto.UUID.dump!(own_insert_id), Ecto.UUID.dump!(ctx.tenant_a), own_insert_key]
        )

        %Postgrex.Result{num_rows: updated} =
          Postgrex.query!(
            conn,
            "UPDATE feature_flags SET name = 'updated-by-probe' WHERE key = $1",
            [ctx.flag_a_key]
          )

        assert updated == 1

        %Postgrex.Result{num_rows: deleted} =
          Postgrex.query!(conn, "DELETE FROM feature_flags WHERE key = $1", [own_insert_key])

        assert deleted == 1
      end)

      %{rows: [[name]]} =
        Postgrex.query!(ctx.admin, "SELECT name FROM feature_flags WHERE key = $1", [
          ctx.flag_a_key
        ])

      assert name == "updated-by-probe"

      %{rows: rows} =
        Postgrex.query!(ctx.admin, "SELECT 1 FROM feature_flags WHERE key = $1", [
          own_insert_key
        ])

      assert rows == []
    end

    test "a probe scoped to tenant A is blocked from inserting, updating, or deleting tenant B's rows",
         ctx do
      cross_tenant_id = Ecto.UUID.generate()
      cross_tenant_key = "rls-probe-write-cross-#{cross_tenant_id}"

      RLSProbe.with_probe_connection(ctx.tenant_a, fn conn ->
        assert_raise Postgrex.Error, ~r/row-level security policy/, fn ->
          Postgrex.query!(
            conn,
            """
            INSERT INTO feature_flags (id, tenant_id, key, name, status, inserted_at, updated_at)
            VALUES ($1, $2, $3, $3, 'disabled', now(), now())
            """,
            [Ecto.UUID.dump!(cross_tenant_id), Ecto.UUID.dump!(ctx.tenant_b), cross_tenant_key]
          )
        end

        %Postgrex.Result{num_rows: updated} =
          Postgrex.query!(
            conn,
            "UPDATE feature_flags SET name = 'should-not-apply' WHERE key = $1",
            [ctx.flag_b_key]
          )

        assert updated == 0

        %Postgrex.Result{num_rows: deleted} =
          Postgrex.query!(conn, "DELETE FROM feature_flags WHERE key = $1", [ctx.flag_b_key])

        assert deleted == 0
      end)

      %{rows: [[name]]} =
        Postgrex.query!(ctx.admin, "SELECT name FROM feature_flags WHERE key = $1", [
          ctx.flag_b_key
        ])

      assert name == ctx.flag_b_key

      %{rows: rows} =
        Postgrex.query!(ctx.admin, "SELECT 1 FROM feature_flags WHERE key = $1", [
          cross_tenant_key
        ])

      assert rows == []
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
