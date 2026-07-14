defmodule ExperimentHubWeb.UserControllerTest do
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

  describe "GET /api/v1/users" do
    test "lists users for the current tenant only", %{conn: conn, tenant: tenant} do
      user = user_fixture(%{tenant: tenant, email: "editor@example.com", role: "editor"})

      other_tenant = tenant_fixture()
      _other_user = user_fixture(%{tenant: other_tenant, email: "other@example.com"})

      conn = get(conn, "/api/v1/users")
      response = json_response(conn, 200)

      emails = Enum.map(response["data"], & &1["email"])
      assert user.email in emails
      refute "other@example.com" in emails
    end
  end

  describe "POST /api/v1/users" do
    test "creates a tenant-scoped user", %{conn: conn, tenant: tenant} do
      conn =
        post(conn, "/api/v1/users", %{
          "email" => "new-user@example.com",
          "password" => "ValidP@ssword123",
          "role" => "viewer"
        })

      response = json_response(conn, 201)

      assert response["data"]["email"] == "new-user@example.com"
      assert response["data"]["role"] == "viewer"
      assert response["data"]["tenant_id"] == tenant.id
    end
  end

  describe "GET /api/v1/users/:id" do
    test "shows a user", %{conn: conn, tenant: tenant} do
      user = user_fixture(%{tenant: tenant, email: "show-user@example.com"})

      conn = get(conn, "/api/v1/users/#{user.id}")
      response = json_response(conn, 200)

      assert response["data"]["id"] == user.id
      assert response["data"]["email"] == "show-user@example.com"
    end
  end

  describe "PUT /api/v1/users/:id" do
    test "updates a user role", %{conn: conn, tenant: tenant} do
      user = user_fixture(%{tenant: tenant, email: "update-user@example.com", role: "viewer"})

      conn = put(conn, "/api/v1/users/#{user.id}", %{"role" => "admin"})
      response = json_response(conn, 200)

      assert response["data"]["role"] == "admin"
      assert Tenants.get_user!(user.id).role == "admin"
    end
  end

  describe "DELETE /api/v1/users/:id" do
    test "removes a user", %{conn: conn, tenant: tenant} do
      user = user_fixture(%{tenant: tenant, email: "remove-user@example.com"})

      conn = delete(conn, "/api/v1/users/#{user.id}")

      assert response(conn, 204)
      refute Tenants.get_user(user.id)
    end
  end
end
