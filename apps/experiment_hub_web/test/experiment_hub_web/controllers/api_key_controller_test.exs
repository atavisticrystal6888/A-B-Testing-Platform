defmodule ExperimentHubWeb.ApiKeyControllerTest do
  use ExperimentHubWeb.ConnCase

  alias ExperimentHub.Repo
  alias ExperimentHub.Tenants

  setup %{conn: conn} do
    tenant = tenant_fixture()
    admin_key = api_key_fixture(%{tenant: tenant, name: "Admin Key"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-api-key", admin_key.raw_key)

    Repo.put_tenant_id(tenant.id)

    %{conn: conn, tenant: tenant}
  end

  describe "GET /api/v1/api-keys" do
    test "lists API keys for the current tenant only", %{conn: conn, tenant: tenant} do
      managed_key = api_key_fixture(%{tenant: tenant, name: "Production SDK Key"})

      other_tenant = tenant_fixture()
      _other_key = api_key_fixture(%{tenant: other_tenant, name: "Other Tenant Key"})

      conn = get(conn, "/api/v1/api-keys")
      response = json_response(conn, 200)

      names = Enum.map(response["data"], & &1["name"])
      assert "Production SDK Key" in names
      refute "Other Tenant Key" in names

      assert Enum.any?(response["data"], fn key ->
               key["id"] == managed_key.id and
                 key["prefix"] == managed_key.key_prefix and
                 key["key_prefix"] == managed_key.key_prefix and
                 not Map.has_key?(key, "key")
             end)
    end
  end

  describe "POST /api/v1/api-keys" do
    test "generates an API key and returns the raw key once", %{conn: conn} do
      conn = post(conn, "/api/v1/api-keys", %{"name" => "Production SDK Key"})
      response = json_response(conn, 201)

      assert response["message"] == "Store this key securely. It will not be shown again."
      assert response["data"]["name"] == "Production SDK Key"
      assert response["data"]["key"] =~ "eh_live_"
      assert response["data"]["prefix"] == String.slice(response["data"]["key"], 0, 8)
      assert response["data"]["key_prefix"] == response["data"]["prefix"]
    end
  end

  describe "DELETE /api/v1/api-keys/:id" do
    test "revokes an API key", %{conn: conn, tenant: tenant} do
      managed_key = api_key_fixture(%{tenant: tenant, name: "Retired Key"})

      conn = delete(conn, "/api/v1/api-keys/#{managed_key.id}")

      assert response(conn, 204)
      assert Tenants.get_api_key!(managed_key.id).revoked_at
    end
  end
end
