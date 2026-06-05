defmodule ExperimentHubWeb.Plugs.TenantContext do
  @moduledoc """
  Sets `SET LOCAL app.current_tenant_id` on each request for RLS enforcement.
  Requires `tenant_id` to be set in conn.assigns (by the auth plug).
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
        conn
    end
  end
end
