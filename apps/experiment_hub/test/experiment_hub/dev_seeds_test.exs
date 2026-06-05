defmodule ExperimentHub.DevSeedsTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.DevSeeds
  alias ExperimentHub.Tenants

  describe "seed_local_admin!/0" do
    test "creates the local dev tenant and admin user idempotently" do
      first = DevSeeds.seed_local_admin!()
      second = DevSeeds.seed_local_admin!()

      assert first.tenant.id == second.tenant.id
      assert first.user.id == second.user.id
      assert first.tenant.slug == "local-dev"
      assert first.user.email == "admin@local.dev"
      assert first.user.role == "admin"

      assert {:ok, user} = Tenants.authenticate_user("admin@local.dev", "ValidP@ssword123")
      assert user.id == second.user.id
    end

    test "updates the existing tenant name, user role, and password" do
      tenant = tenant_fixture(%{name: "Old Dev Tenant", slug: "local-dev"})

      user =
        user_fixture(%{
          tenant: tenant,
          email: "admin@local.dev",
          role: "viewer",
          password: "OldPassword123!"
        })

      result = DevSeeds.seed_local_admin!()

      assert result.tenant.id == tenant.id
      assert result.tenant.name == "Local Dev Tenant"
      assert result.user.id == user.id
      assert result.user.role == "admin"

      assert {:ok, refreshed_user} =
               Tenants.authenticate_user("admin@local.dev", "ValidP@ssword123")

      assert refreshed_user.id == user.id
    end
  end
end
