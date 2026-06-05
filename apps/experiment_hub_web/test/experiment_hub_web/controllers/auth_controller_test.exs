defmodule ExperimentHubWeb.Controllers.AuthControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  describe "POST /api/v1/auth/login" do
    test "returns access token on valid tenant-scoped login", %{conn: conn} do
      tenant = tenant_fixture()
      user = user_fixture(tenant: tenant, password: "ValidP@ssword123")

      conn =
        post(conn, "/api/v1/auth/login", %{
          tenant_id: tenant.id,
          email: user.email,
          password: "ValidP@ssword123"
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "bearer",
               "user" => %{"id" => user_id, "tenant_id" => tenant_id}
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert user_id == user.id
      assert tenant_id == tenant.id
    end

    test "accepts tenant slug on valid tenant-scoped login", %{conn: conn} do
      tenant = tenant_fixture(%{slug: "local-dev"})
      user = user_fixture(tenant: tenant, password: "ValidP@ssword123")

      conn =
        post(conn, "/api/v1/auth/login", %{
          tenant_id: tenant.slug,
          email: user.email,
          password: "ValidP@ssword123"
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "bearer",
               "user" => %{"id" => user_id, "tenant_id" => tenant_id}
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert user_id == user.id
      assert tenant_id == tenant.id
    end

    test "supports email-only login when email is unique across tenants", %{conn: conn} do
      user = user_fixture(password: "ValidP@ssword123")

      conn =
        post(conn, "/api/v1/auth/login", %{
          email: user.email,
          password: "ValidP@ssword123"
        })

      assert %{"access_token" => access_token, "user" => %{"id" => user_id}} =
               json_response(conn, 200)

      assert is_binary(access_token)
      assert user_id == user.id
    end

    test "returns tenant_required when same email exists in multiple tenants", %{conn: conn} do
      email = "shared-login@example.com"
      tenant_a = tenant_fixture()
      tenant_b = tenant_fixture()

      _ = user_fixture(tenant: tenant_a, email: email, password: "ValidP@ssword123")
      _ = user_fixture(tenant: tenant_b, email: email, password: "ValidP@ssword123")

      conn =
        post(conn, "/api/v1/auth/login", %{
          email: email,
          password: "ValidP@ssword123"
        })

      assert %{"error" => "tenant_required"} = json_response(conn, 400)
    end

    test "returns 401 on invalid credentials", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          email: "nobody@example.com",
          password: "wrong"
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end
  end
end
