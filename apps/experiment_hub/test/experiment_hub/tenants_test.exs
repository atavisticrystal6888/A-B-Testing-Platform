defmodule ExperimentHub.TenantsTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Tenants
  alias ExperimentHub.Tenants.{Tenant, User, ApiKey}

  describe "tenants" do
    test "create_tenant/1 with valid attrs creates a tenant" do
      attrs = %{"name" => "Acme Corp", "slug" => "acme-corp"}
      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(attrs)
      assert tenant.name == "Acme Corp"
      assert tenant.slug == "acme-corp"
      assert tenant.settings == %{}
    end

    test "create_tenant/1 with invalid slug returns error" do
      attrs = %{"name" => "Bad Slug", "slug" => "BAD SLUG!"}
      assert {:error, changeset} = Tenants.create_tenant(attrs)
      assert %{slug: _} = errors_on(changeset)
    end

    test "create_tenant/1 with duplicate slug returns error" do
      attrs = %{"name" => "First", "slug" => "unique-slug"}
      assert {:ok, _} = Tenants.create_tenant(attrs)
      assert {:error, changeset} = Tenants.create_tenant(%{attrs | "name" => "Second"})
      assert %{slug: _} = errors_on(changeset)
    end

    test "list_tenants/0 returns all tenants" do
      tenant = tenant_fixture()
      assert tenant in Tenants.list_tenants()
    end

    test "get_tenant/1 returns the tenant" do
      tenant = tenant_fixture()
      assert Tenants.get_tenant(tenant.id) == tenant
    end

    test "get_tenant_by_slug/1 returns the tenant" do
      tenant = tenant_fixture()
      assert Tenants.get_tenant_by_slug(tenant.slug) == tenant
    end

    test "update_tenant/2 updates the tenant" do
      tenant = tenant_fixture()
      assert {:ok, updated} = Tenants.update_tenant(tenant, %{"name" => "Updated"})
      assert updated.name == "Updated"
    end

    test "delete_tenant/1 deletes the tenant" do
      tenant = tenant_fixture()
      assert {:ok, _} = Tenants.delete_tenant(tenant)
      assert Tenants.get_tenant(tenant.id) == nil
    end
  end

  describe "users" do
    test "create_user/1 with valid attrs creates a user" do
      tenant = tenant_fixture()

      attrs = %{
        "email" => "user@example.com",
        "password" => "password123!",
        "role" => "editor",
        "tenant_id" => tenant.id
      }

      assert {:ok, %User{} = user} = Tenants.create_user(attrs)
      assert user.email == "user@example.com"
      assert user.role == "editor"
      assert user.tenant_id == tenant.id
      assert user.password_hash != nil
      # Password virtual field should be cleared
      assert user.password == nil
    end

    test "create_user/1 with invalid role returns error" do
      tenant = tenant_fixture()

      attrs = %{
        "email" => "user@example.com",
        "password" => "password123!",
        "role" => "superadmin",
        "tenant_id" => tenant.id
      }

      assert {:error, changeset} = Tenants.create_user(attrs)
      assert %{role: _} = errors_on(changeset)
    end

    test "create_user/1 with duplicate email per tenant returns error" do
      tenant = tenant_fixture()

      attrs = %{
        "email" => "dup@example.com",
        "password" => "password123!",
        "role" => "viewer",
        "tenant_id" => tenant.id
      }

      assert {:ok, _} = Tenants.create_user(attrs)
      assert {:error, changeset} = Tenants.create_user(attrs)
      assert %{tenant_id: _} = errors_on(changeset)
    end

    test "list_users/1 returns users for a specific tenant" do
      tenant = tenant_fixture()
      user = user_fixture(tenant: tenant)
      other_tenant = tenant_fixture()
      _other_user = user_fixture(tenant: other_tenant)

      users = Tenants.list_users(tenant.id)
      assert length(users) == 1
      assert hd(users).id == user.id
    end

    test "authenticate_user/3 with valid credentials returns user" do
      tenant = tenant_fixture()
      _user = user_fixture(tenant: tenant, email: "auth@example.com", password: "validpass123!")

      assert {:ok, user} =
               Tenants.authenticate_user(tenant.id, "auth@example.com", "validpass123!")

      assert user.email == "auth@example.com"
    end

    test "authenticate_user/3 with invalid password returns error" do
      tenant = tenant_fixture()
      _user = user_fixture(tenant: tenant, email: "auth2@example.com", password: "validpass123!")

      assert {:error, :invalid_credentials} =
               Tenants.authenticate_user(tenant.id, "auth2@example.com", "wrongpassword")
    end

    test "update_user/2 updates user fields" do
      user = user_fixture()
      assert {:ok, updated} = Tenants.update_user(user, %{"role" => "admin"})
      assert updated.role == "admin"
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, _} = Tenants.delete_user(user)
      assert Tenants.get_user(user.id) == nil
    end
  end

  describe "api_keys" do
    test "create_api_key/1 generates key with eh_live_ prefix" do
      tenant = tenant_fixture()
      attrs = %{"name" => "Production Key", "tenant_id" => tenant.id}

      assert {:ok, %ApiKey{} = api_key} = Tenants.create_api_key(attrs)
      assert api_key.raw_key != nil
      assert String.starts_with?(api_key.raw_key, "eh_live_")
      assert api_key.key_prefix == "eh_live_"
      assert api_key.key_hash != nil
    end

    test "verify_api_key/1 finds active key" do
      tenant = tenant_fixture()
      {:ok, api_key} = Tenants.create_api_key(%{"name" => "Test", "tenant_id" => tenant.id})

      assert {:ok, found} = Tenants.verify_api_key(api_key.raw_key)
      assert found.id == api_key.id
      assert found.tenant_id == tenant.id
    end

    test "verify_api_key/1 rejects invalid key" do
      assert {:error, :not_found} = Tenants.verify_api_key("eh_live_invalidkey")
    end

    test "verify_api_key/1 rejects revoked key" do
      tenant = tenant_fixture()
      {:ok, api_key} = Tenants.create_api_key(%{"name" => "Revoke", "tenant_id" => tenant.id})
      {:ok, _revoked} = Tenants.revoke_api_key(api_key)

      assert {:error, :revoked_or_expired} = Tenants.verify_api_key(api_key.raw_key)
    end

    test "list_api_keys/1 returns keys for a tenant" do
      tenant = tenant_fixture()
      {:ok, _} = Tenants.create_api_key(%{"name" => "Key1", "tenant_id" => tenant.id})
      {:ok, _} = Tenants.create_api_key(%{"name" => "Key2", "tenant_id" => tenant.id})

      keys = Tenants.list_api_keys(tenant.id)
      assert length(keys) == 2
    end

    test "revoke_api_key/1 sets revoked_at" do
      tenant = tenant_fixture()
      {:ok, api_key} = Tenants.create_api_key(%{"name" => "Revoke", "tenant_id" => tenant.id})

      assert {:ok, revoked} = Tenants.revoke_api_key(api_key)
      assert revoked.revoked_at != nil
    end
  end
end
