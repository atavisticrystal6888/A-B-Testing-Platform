defmodule ExperimentHubWeb.Plugs.SessionAuthTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias ExperimentHubWeb.Plugs.SessionAuth

  @user %{id: "user-123", tenant_id: "tenant-456", role: "editor"}

  describe "generate_token/1 and verify_token/1" do
    test "roundtrips claims" do
      token = SessionAuth.generate_token(@user)

      assert {:ok, claims} = SessionAuth.verify_token(token)
      assert claims["sub"] == @user.id
      assert claims["tenant_id"] == @user.tenant_id
      assert claims["role"] == @user.role
    end
  end

  describe "call/2" do
    test "assigns auth fields and current_scope when token is valid" do
      token = SessionAuth.generate_token(@user)

      conn =
        :get
        |> conn("/")
        |> put_req_header("authorization", "Bearer " <> token)
        |> SessionAuth.call(SessionAuth.init([]))

      assert conn.assigns[:current_user_id] == @user.id
      assert conn.assigns[:tenant_id] == @user.tenant_id
      assert conn.assigns[:user_role] == @user.role
      assert conn.assigns[:auth_method] == :jwt

      assert conn.assigns[:current_scope] == %{
               tenant_id: @user.tenant_id,
               user_id: @user.id,
               role: @user.role
             }
    end
  end
end
