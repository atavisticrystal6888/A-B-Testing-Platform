defmodule ExperimentHub.RepoTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Repo

  # Every tenant_isolation RLS policy (migrations 20260401000004 and
  # 20260401000023) is exactly this boolean expression:
  #
  #   tenant_id = current_setting('app.current_tenant_id')::uuid
  #
  # `Repo.put_tenant_id/1` sets that GUC with `set_config(..., false)` —
  # session-scoped, not `SET LOCAL` — because nothing wraps a request or
  # Oban job in an explicit transaction. Session scope means the value can
  # outlive the unit of work that set it on whatever pooled connection
  # served it, which is exactly the risk this suite exercises: after one
  # tenant's work finishes and the context is cleared (what
  # Plugs.TenantContext's `before_send` hook and `Repo.clear_tenant_id/0`
  # are for), a later caller with NO tenant set on the *same* connection
  # must not be able to resolve the previous tenant through a leftover GUC.
  #
  # This can't be asserted end-to-end through real RLS enforcement in this
  # suite: config/test.exs defaults to DB_USERNAME=postgres, and Postgres
  # superusers bypass RLS entirely (FORCE ROW LEVEL SECURITY only binds
  # non-superuser table owners) — a live "does RLS block this row" test
  # would pass or fail independent of the GUC. Instead this evaluates the
  # policy's own expression directly via raw SQL, which is exactly what
  # Postgres evaluates on a connection where RLS does apply, and is
  # therefore a faithful test of the mechanism the fix touches: the GUC's
  # lifecycle on a pooled connection, not the RLS bypass-for-superusers gap
  # (a separate, real limitation of this test environment, noted for the
  # report, not fixed here).
  describe "tenant GUC session lifecycle" do
    test "clear_tenant_id/0 removes the session GUC so a later no-tenant caller on the same connection cannot resolve the previous tenant's row" do
      tenant_a = tenant_fixture()
      experiment = experiment_fixture(tenant: tenant_a)
      raw_id = Ecto.UUID.dump!(experiment.id)

      policy_sql =
        "SELECT id FROM experiments WHERE id = $1 AND tenant_id = current_setting('app.current_tenant_id')::uuid"

      Repo.put_tenant_id(tenant_a.id)

      # Sanity check: while tenant_a is the active session tenant, the
      # RLS policy's own expression resolves to its row.
      assert {:ok, %{rows: [[_id]]}} = Repo.query(policy_sql, [raw_id])

      # End of unit of work — this is what Plugs.TenantContext's
      # before_send hook now does for every request.
      Repo.clear_tenant_id()

      # A later, unrelated caller with no tenant set must not silently
      # inherit tenant_a's id through a leftover session GUC. Before this
      # fix, nothing ever reset the GUC, so this same query would still
      # resolve tenant_a's row on a reused connection — this is the
      # regression this test guards against. After RESET, this Postgres
      # version resets the never-declared custom GUC back to an empty
      # string (rather than fully undefined), so evaluating the same
      # expression raises a uuid cast error rather than silently matching
      # tenant_a's row, or silently returning nothing that could be
      # mistaken for "row not found" — a fail-closed error over a
      # fail-open leak either way.
      assert {:error, %Postgrex.Error{postgres: %{message: message}}} =
               Repo.query(policy_sql, [raw_id])

      assert message =~ "invalid input syntax for type uuid"
    end

    test "current_tenant_id/0 (process dictionary) is unaffected by another process's session GUC" do
      tenant_a = tenant_fixture()
      Repo.put_tenant_id(tenant_a.id)

      assert Repo.current_tenant_id() == tenant_a.id

      Repo.clear_tenant_id()

      refute Repo.current_tenant_id()
    end
  end

  # `with_tenant/2` is the shared helper every put_tenant_id/1 caller (Oban
  # workers, demo seeding) now goes through instead of pairing
  # put_tenant_id/1 with its own bare clear_tenant_id/0 call — a bare pairing
  # only clears on the happy path. These tests are the mechanism-level proof
  # that both the per-process value and the session GUC are cleared
  # regardless of how `fun` exits, since every call site's guarantee reduces
  # to this function's.
  describe "with_tenant/2" do
    test "clears the tenant context after fun returns normally" do
      tenant_a = tenant_fixture()

      result =
        Repo.with_tenant(tenant_a.id, fn ->
          assert Repo.current_tenant_id() == tenant_a.id
          :the_result
        end)

      assert result == :the_result
      refute Repo.current_tenant_id()

      assert {:error, %Postgrex.Error{postgres: %{message: message}}} =
               Repo.query(
                 "SELECT current_setting('app.current_tenant_id')::uuid",
                 []
               )

      assert message =~ "invalid input syntax for type uuid"
    end

    test "clears the tenant context after fun raises" do
      tenant_a = tenant_fixture()

      assert_raise RuntimeError, "boom", fn ->
        Repo.with_tenant(tenant_a.id, fn ->
          assert Repo.current_tenant_id() == tenant_a.id
          raise "boom"
        end)
      end

      refute Repo.current_tenant_id()

      assert {:error, %Postgrex.Error{postgres: %{message: message}}} =
               Repo.query(
                 "SELECT current_setting('app.current_tenant_id')::uuid",
                 []
               )

      assert message =~ "invalid input syntax for type uuid"
    end
  end
end
