defmodule ExperimentHubWeb.UserSocketTest do
  use ExUnit.Case, async: true

  alias ExperimentHubWeb.Plugs.SessionAuth
  alias ExperimentHubWeb.UserSocket

  @user %{id: "user-123", tenant_id: "tenant-456", role: "admin"}

  describe "connect/3" do
    test "connects with a valid session JWT" do
      token = SessionAuth.generate_token(@user)
      socket = %Phoenix.Socket{}

      assert {:ok, socket} = UserSocket.connect(%{"token" => token}, socket, %{})
      assert socket.assigns.user_id == @user.id
      assert socket.assigns.tenant_id == @user.tenant_id
      assert socket.assigns.role == @user.role
    end

    test "rejects invalid token" do
      socket = %Phoenix.Socket{}

      assert :error == UserSocket.connect(%{"token" => "invalid.token.value"}, socket, %{})
    end
  end
end
