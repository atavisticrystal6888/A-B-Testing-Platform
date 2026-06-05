defmodule ExperimentHubWeb.UserController do
  use ExperimentHubWeb, :controller
  action_fallback ExperimentHubWeb.FallbackController

  alias ExperimentHub.Tenants

  def index(conn, _params) do
    tenant_id = conn.assigns[:tenant_id]
    users = Tenants.list_users(tenant_id)

    json(conn, %{data: Enum.map(users, &format_user/1)})
  end

  def show(conn, %{"id" => id}) do
    user = Tenants.get_user!(id)
    json(conn, %{data: format_user(user)})
  end

  def create(conn, params) do
    tenant_id = conn.assigns[:tenant_id]
    attrs = Map.put(params, "tenant_id", tenant_id)

    case Tenants.create_user(attrs) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{data: format_user(user)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Tenants.get_user!(id)

    case Tenants.update_user(user, params) do
      {:ok, user} ->
        json(conn, %{data: format_user(user)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Tenants.get_user!(id)
    Tenants.delete_user(user)
    send_resp(conn, :no_content, "")
  end

  defp format_user(user) do
    %{
      id: user.id,
      email: user.email,
      role: user.role,
      tenant_id: user.tenant_id,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
