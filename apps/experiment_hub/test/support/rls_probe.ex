defmodule ExperimentHub.TestSupport.RLSProbe do
  @moduledoc """
  Exercises RLS policies through a genuinely non-superuser, non-BYPASSRLS
  Postgres role.

  Every existing RLS-flavored test (`ExperimentHub.RLSIntegrationTest`,
  `ExperimentHub.RepoTest`'s GUC lifecycle tests) runs through
  `ExperimentHub.Repo`. In this environment that role has either SUPERUSER
  or an explicit BYPASSRLS attribute (see
  `.superpowers/fixes/elixir-correctness-report.md`'s "RLS may be
  structurally inert in this test environment" finding), so those tests
  actually exercise `Repo.prepare_query/3`'s Ecto-level `WHERE tenant_id =
  ...` injection -- they'd pass or fail identically whether or not the
  database's own RLS policies did anything at all. None of them prove
  Postgres itself enforces tenant isolation.

  This module gives tests a second, separate connection authenticated as a
  role with neither SUPERUSER nor BYPASSRLS, so `FORCE ROW LEVEL SECURITY`
  (applied to every tenant-scoped table by migrations `20260401000004` and
  `20260401000023`) genuinely binds it, and a raw SQL query issued directly
  against that connection (bypassing `prepare_query/3` entirely -- there is
  no Ecto involved at all) proves the database enforces the policy on its
  own.

  Because this needs a role-level Postgres object (not scoped to any one
  database) and a second physical connection outside
  `Ecto.Adapters.SQL.Sandbox`'s per-test transaction -- a sandboxed
  transaction's writes are invisible to any other connection until it
  commits, and it never commits -- tests using this module do not run
  through `ExperimentHub.DataCase`. They manage their own fixture rows and
  cleanup via a plain, autocommitting Postgrex connection (`start_admin_connection!/0`).
  """

  @probe_role "experiment_hub_rls_probe"
  @probe_password "rls-probe-test-only"

  @doc """
  Opens a plain (non-Sandbox) Postgrex connection using the same
  credentials `ExperimentHub.Repo` is configured with in this environment --
  a superuser/table-owner role that can create the probe role, grant it
  privileges, and insert/delete fixture rows with immediate, real commits
  (every `Postgrex.query!/3` outside an explicit transaction autocommits).
  """
  def start_admin_connection! do
    start_connection!(
      username: Keyword.fetch!(repo_config(), :username),
      password: Keyword.fetch!(repo_config(), :password)
    )
  end

  @doc """
  Opens a Postgrex connection authenticated as the probe role, against the
  same host/database `ExperimentHub.Repo` is configured for.
  """
  def start_probe_connection! do
    start_connection!(username: @probe_role, password: @probe_password)
  end

  @doc """
  Ensures the probe role exists -- idempotent, so it's safe to call every
  test run against a persistent local database, not just a freshly created
  one -- and can `SELECT` the given tables, with neither `SUPERUSER` nor
  `BYPASSRLS` so `FORCE ROW LEVEL SECURITY` actually binds it.
  """
  def ensure_probe_role!(admin, tables) do
    Postgrex.query!(
      admin,
      """
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '#{@probe_role}') THEN
          CREATE ROLE #{@probe_role} LOGIN PASSWORD '#{@probe_password}' NOSUPERUSER NOBYPASSRLS;
        END IF;
      END
      $$;
      """,
      []
    )

    Postgrex.query!(admin, "GRANT USAGE ON SCHEMA public TO #{@probe_role}", [])

    Enum.each(tables, fn table ->
      Postgrex.query!(admin, "GRANT SELECT ON #{table} TO #{@probe_role}", [])
    end)

    :ok
  end

  @doc """
  Runs `query_fun.(conn)` on a *fresh* probe-role connection with
  `app.current_tenant_id` set to `tenant_id` -- or left completely unset
  when `tenant_id` is `nil`, to exercise the fail-closed no-context case.
  A fresh connection per call means a GUC set by an earlier call in the
  same test can't leak into this one and mask a real regression.
  """
  def with_probe_connection(tenant_id, query_fun) do
    conn = start_probe_connection!()

    try do
      if tenant_id do
        Postgrex.query!(conn, "SELECT set_config('app.current_tenant_id', $1, false)", [
          tenant_id
        ])
      end

      query_fun.(conn)
    after
      GenServer.stop(conn)
    end
  end

  defp start_connection!(creds) do
    config = repo_config()

    {:ok, conn} =
      Postgrex.start_link(
        hostname: Keyword.fetch!(config, :hostname),
        port: Keyword.fetch!(config, :port),
        database: Keyword.fetch!(config, :database),
        username: Keyword.fetch!(creds, :username),
        password: Keyword.fetch!(creds, :password)
      )

    conn
  end

  defp repo_config, do: Application.fetch_env!(:experiment_hub, ExperimentHub.Repo)
end
