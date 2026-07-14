defmodule ExperimentHubWeb.ApiKeyController do
  use ExperimentHubWeb, :controller
  action_fallback ExperimentHubWeb.FallbackController

  alias ExperimentHub.Tenants

  def index(conn, _params) do
    tenant_id = conn.assigns[:tenant_id]
    api_keys = Tenants.list_api_keys(tenant_id)

    json(conn, %{
      data: Enum.map(api_keys, &format_api_key/1)
    })
  end

  def create(conn, params) do
    tenant_id = conn.assigns[:tenant_id]
    name = params["name"] || "default"

    attrs =
      params
      |> Map.take(["expires_at"])
      |> Map.put("name", name)
      |> Map.put("tenant_id", tenant_id)

    case Tenants.create_api_key(attrs) do
      {:ok, api_key} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: Map.put(format_api_key(api_key), :key, Map.get(api_key, :raw_key)),
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

  defp format_api_key(api_key) do
    %{
      id: api_key.id,
      key_prefix: api_key.key_prefix,
      prefix: api_key.key_prefix,
      name: api_key.name,
      expires_at: api_key.expires_at,
      revoked_at: api_key.revoked_at,
      last_used_at: api_key.last_used_at,
      inserted_at: api_key.inserted_at
    }
  end
end
