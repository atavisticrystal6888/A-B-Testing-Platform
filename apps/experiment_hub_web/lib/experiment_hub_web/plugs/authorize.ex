defmodule ExperimentHubWeb.Plugs.Authorize do
  @moduledoc """
  RBAC authorization Plug enforcing viewer/editor/admin role checks.
  Must be placed after authentication plugs that set `user_role` or `api_key` in assigns.

  Usage in router:
      plug ExperimentHubWeb.Plugs.Authorize, roles: [:editor, :admin]
  """

  import Plug.Conn

  @role_hierarchy %{
    "admin" => 3,
    "editor" => 2,
    "viewer" => 1
  }

  def init(opts) do
    roles = Keyword.fetch!(opts, :roles)
    %{roles: Enum.map(roles, &to_string/1)}
  end

  def call(conn, %{roles: allowed_roles}) do
    role = get_role(conn)

    if role && role in allowed_roles do
      conn
    else
      conn
      |> put_status(403)
      |> Phoenix.Controller.json(%{
        error: "forbidden",
        message: "Insufficient permissions. Required role: #{Enum.join(allowed_roles, " or ")}"
      })
      |> halt()
    end
  end

  defp get_role(conn) do
    # JWT auth sets user_role directly
    # API key auth — API keys act as admin by default for programmatic access
    case conn.assigns do
      %{user_role: role} -> role
      %{api_key: _api_key} -> "admin"
      _ -> nil
    end
  end

  @doc """
  Returns the numeric level for a role. Higher = more permissions.
  """
  def role_level(role), do: Map.get(@role_hierarchy, to_string(role), 0)
end
