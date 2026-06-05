defmodule ExperimentHubWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Validates the `X-API-Key` header against the api_keys table.
  Sets `tenant_id` and `api_key` in conn.assigns on success.
  """

  import Plug.Conn
  alias ExperimentHub.Tenants

  def init(opts), do: opts

  def call(conn, _opts) do
    with [raw_key] <- get_req_header(conn, "x-api-key"),
         {:ok, api_key} <- Tenants.verify_api_key(raw_key) do
      conn
      |> assign(:tenant_id, api_key.tenant_id)
      |> assign(:current_scope, %{tenant_id: api_key.tenant_id, user_id: nil, role: "admin"})
      |> assign(:api_key, api_key)
      |> assign(:auth_method, :api_key)
    else
      [] ->
        conn

      {:error, _reason} ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{
          error: "unauthorized",
          message: "Invalid or expired API key"
        })
        |> halt()
    end
  end
end
