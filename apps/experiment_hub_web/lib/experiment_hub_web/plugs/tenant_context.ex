defmodule ExperimentHubWeb.Plugs.TenantContext do
  @moduledoc """
  Resolves `conn.assigns[:tenant_id]` (set by the auth plug) into the
  request's tenant scope and requires it be present.

  This sets two things: a per-process value (`Repo.put_tenant_id/1`'s
  `Process.put/2`) that `ExperimentHub.Repo.prepare_query/3` uses to inject
  `WHERE tenant_id = ...` into Ecto queries, and a Postgres session GUC
  (`app.current_tenant_id`, via `SELECT set_config(..., false)` — session-
  scoped, **not** `SET LOCAL`/transaction-scoped, because requests are not
  wrapped in an explicit transaction) that RLS policies read as a second,
  DB-enforced guard for query paths the process-dictionary value can't
  reach (raw SQL, `skip_tenant_scope: true` callers, Oban workers).

  Because it's session-scoped, the GUC can outlive this request on whatever
  pooled connection served it. This plug registers a `before_send` callback
  to reset it once the response is sent, bounding — but not eliminating —
  that window; see the comment on `ExperimentHub.Repo.clear_tenant_id/0` for
  the residual risk this does not close.
  """

  import Plug.Conn
  alias ExperimentHub.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:tenant_id] do
      nil ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: "unauthorized", message: "Missing tenant context"})
        |> halt()

      tenant_id ->
        Repo.put_tenant_id(tenant_id)

        register_before_send(conn, fn conn ->
          Repo.clear_tenant_id()
          conn
        end)
    end
  end
end
