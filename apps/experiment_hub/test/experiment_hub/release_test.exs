defmodule ExperimentHub.ReleaseTest do
  use ExperimentHub.DataCase, async: false

  alias ExperimentHub.Release
  alias ExperimentHub.Tenants

  test "creates a tenant, admin user, and API key on a fresh deployment" do
    assert {:ok, %{tenant: tenant, user: user, api_key: api_key}} =
             Release.bootstrap_first_tenant(
               "Acme Corp",
               "acme-#{System.unique_integer([:positive])}",
               "admin@acme.example",
               "ChangeMe123!"
             )

    assert tenant.name == "Acme Corp"
    assert user.email == "admin@acme.example"
    assert user.role == "admin"
    assert user.tenant_id == tenant.id
    assert is_binary(api_key.raw_key)
  end

  test "refuses to run again once any tenant exists" do
    slug = "acme-#{System.unique_integer([:positive])}"

    assert {:ok, _} =
             Release.bootstrap_first_tenant(
               "Acme Corp",
               slug,
               "admin@acme.example",
               "ChangeMe123!"
             )

    assert {:error, :tenants_already_exist} =
             Release.bootstrap_first_tenant(
               "Other Co",
               "other-#{System.unique_integer([:positive])}",
               "admin@other.example",
               "ChangeMe123!"
             )

    # only the first tenant was created — refused, not overwritten
    assert length(Tenants.list_tenants()) == 1
  end
end
