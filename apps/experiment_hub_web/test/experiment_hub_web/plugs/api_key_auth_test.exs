defmodule ExperimentHubWeb.Plugs.ApiKeyAuthTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHubWeb.Plugs.ApiKeyAuth

  describe "call/2" do
    test "authenticates with valid API key", %{conn: conn} do
      tenant = tenant_fixture()
      api_key = api_key_fixture(tenant: tenant)

      conn =
        conn
        |> put_req_header("x-api-key", api_key.raw_key)
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.assigns[:tenant_id] == tenant.id
      assert conn.assigns[:api_key].id == api_key.id
      assert conn.assigns[:auth_method] == :api_key
      refute conn.halted
    end

    test "rejects invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "eh_live_invalidkey123")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.halted
      assert conn.status == 401
    end

    test "passes through when no API key header present", %{conn: conn} do
      conn = ApiKeyAuth.call(conn, ApiKeyAuth.init([]))

      refute conn.halted
      assert conn.assigns[:auth_method] == nil
    end

    test "rejects revoked API key", %{conn: conn} do
      tenant = tenant_fixture()
      api_key = api_key_fixture(tenant: tenant)
      {:ok, _} = ExperimentHub.Tenants.revoke_api_key(api_key)

      conn =
        conn
        |> put_req_header("x-api-key", api_key.raw_key)
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.halted
      assert conn.status == 401
    end
  end
end
