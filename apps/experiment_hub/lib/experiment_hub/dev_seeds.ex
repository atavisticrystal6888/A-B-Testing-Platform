defmodule ExperimentHub.DevSeeds do
  @moduledoc """
  Idempotent development seed helpers.
  """

  alias ExperimentHub.Tenants
  alias ExperimentHub.Tenants.{Tenant, User}

  @tenant_name "Local Dev Tenant"
  @tenant_slug "local-dev"
  @admin_email "admin@local.dev"
  @admin_password "ValidP@ssword123"
  @admin_role "admin"

  @doc """
  Creates or refreshes the default local development tenant and admin account.
  """
  def seed_local_admin! do
    tenant = ensure_tenant!()
    user = ensure_user!(tenant)

    %{
      tenant: tenant,
      user: user,
      password: @admin_password
    }
  end

  defp ensure_tenant! do
    case Tenants.get_tenant_by_slug(@tenant_slug) do
      nil ->
        create_tenant!()

      %Tenant{} = tenant ->
        if tenant.name == @tenant_name do
          tenant
        else
          update_tenant!(tenant, %{"name" => @tenant_name})
        end
    end
  end

  defp ensure_user!(tenant) do
    case Tenants.get_user_by_email(tenant.id, @admin_email) do
      nil ->
        create_user!(tenant)

      %User{} = user ->
        user =
          if user.role == @admin_role do
            user
          else
            update_user!(user, %{"role" => @admin_role})
          end

        update_user_password!(user, %{"password" => @admin_password})
    end
  end

  defp create_tenant! do
    case Tenants.create_tenant(%{"name" => @tenant_name, "slug" => @tenant_slug}) do
      {:ok, tenant} -> tenant
      {:error, changeset} -> raise "local dev tenant seed failed: #{inspect(changeset.errors)}"
    end
  end

  defp update_tenant!(tenant, attrs) do
    case Tenants.update_tenant(tenant, attrs) do
      {:ok, tenant} -> tenant
      {:error, changeset} -> raise "local dev tenant update failed: #{inspect(changeset.errors)}"
    end
  end

  defp create_user!(tenant) do
    case Tenants.create_user(%{
           "tenant_id" => tenant.id,
           "email" => @admin_email,
           "password" => @admin_password,
           "role" => @admin_role
         }) do
      {:ok, user} -> user
      {:error, changeset} -> raise "local dev user seed failed: #{inspect(changeset.errors)}"
    end
  end

  defp update_user!(user, attrs) do
    case Tenants.update_user(user, attrs) do
      {:ok, user} -> user
      {:error, changeset} -> raise "local dev user update failed: #{inspect(changeset.errors)}"
    end
  end

  defp update_user_password!(user, attrs) do
    case Tenants.update_user_password(user, attrs) do
      {:ok, user} ->
        user

      {:error, changeset} ->
        raise "local dev user password update failed: #{inspect(changeset.errors)}"
    end
  end
end
