defmodule ExperimentHubWeb.ApiKeyController do
  use ExperimentHubWeb, :controller
  action_fallback ExperimentHubWeb.FallbackController

  alias ExperimentHub.Tenants

  def index(conn, _params) do
    tenant_id = conn.assigns[:tenant_id]
    api_keys = Tenants.list_api_keys(tenant_id)

    json(conn, %{
      data:
        Enum.map(api_keys, fn key ->
          %{
            id: key.id,
            prefix: key.prefix,
            name: key.name,
            last_used_at: key.last_used_at,
            inserted_at: key.inserted_at
          }
        end)
    })
  end

  def create(conn, params) do
    tenant_id = conn.assigns[:tenant_id]
    name = params["name"] || "default"

    attrs = %{"name" => name, "tenant_id" => tenant_id}

    case Tenants.create_api_key(attrs) do
      {:ok, api_key} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: api_key.id,
            key: Map.get(api_key, :raw_key),
            prefix: api_key.prefix,
            name: api_key.name
          },
          message: "Store this key securely. It will not be shown again."
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    api_key = Tenants.get_api_key!(id)
    Tenants.revoke_api_key(api_key)
    send_resp(conn, :no_content, "")
  end
end
