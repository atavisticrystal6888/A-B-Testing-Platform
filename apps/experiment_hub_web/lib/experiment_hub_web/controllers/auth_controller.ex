defmodule ExperimentHubWeb.AuthController do
  @moduledoc """
  Authentication controller for login/logout (FR-320).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Tenants
  alias ExperimentHubWeb.Plugs.SessionAuth

  def login(conn, %{"tenant_id" => tenant_id, "email" => email, "password" => password}) do
    handle_login_result(conn, Tenants.authenticate_user(tenant_id, email, password))
  end

  def login(conn, %{"email" => email, "password" => password}) do
    handle_login_result(conn, Tenants.authenticate_user(email, password))
  end

  defp handle_login_result(conn, {:ok, user}) do
    token = SessionAuth.generate_token(user)

    json(conn, %{
      access_token: token,
      token_type: "bearer",
      user: %{
        id: user.id,
        email: user.email,
        role: user.role,
        tenant_id: user.tenant_id
      }
    })
  end

  defp handle_login_result(conn, {:error, :tenant_required}) do
    conn
    |> put_status(400)
    |> json(%{
      error: "tenant_required",
      message: "Multiple tenants found for this email. Please provide tenant_id to continue."
    })
  end

  defp handle_login_result(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(401)
    |> json(%{error: "invalid_credentials", message: "Invalid email or password"})
  end

  defp handle_login_result(conn, _result) do
    conn
    |> put_status(401)
    |> json(%{error: "invalid_credentials", message: "Invalid email or password"})
  end

  def logout(conn, _params) do
    json(conn, %{message: "logged_out"})
  end

  def me(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user_id: user_id} when not is_nil(user_id) ->
        user = Tenants.get_user!(user_id)

        json(conn, %{
          data: %{
            id: user.id,
            email: user.email,
            role: user.role,
            tenant_id: user.tenant_id
          }
        })

      _ ->
        conn
        |> put_status(401)
        |> json(%{error: "invalid_session", message: "User session required"})
    end
  end
end
