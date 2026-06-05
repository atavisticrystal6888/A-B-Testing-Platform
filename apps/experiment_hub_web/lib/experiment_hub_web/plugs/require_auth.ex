defmodule ExperimentHubWeb.Plugs.RequireAuth do
  @moduledoc """
  Ensures the request has been authenticated (either via API key or JWT session).
  Must run after ApiKeyAuth and SessionAuth plugs.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:auth_method] do
      conn
    else
      conn
      |> put_status(401)
      |> Phoenix.Controller.json(%{
        error: "unauthorized",
        message:
          "Authentication required. Provide X-API-Key header or Authorization: Bearer token."
      })
      |> halt()
    end
  end
end
