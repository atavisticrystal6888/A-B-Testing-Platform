defmodule ExperimentHubWeb.TenantController do
  @moduledoc """
  REST API for tenant management (FR-115).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Tenants
  alias ExperimentHub.Tenants.TenantSettings
  alias ExperimentHub.Repo

  action_fallback ExperimentHubWeb.FallbackController

  def show(conn, _params) do
    scope = conn.assigns[:current_scope]
    tenant = Tenants.get_tenant!(scope.tenant_id)
    json(conn, %{data: format_tenant(tenant)})
  end

  def update(conn, %{"tenant" => tenant_params}) do
    scope = conn.assigns[:current_scope]
    tenant = Tenants.get_tenant!(scope.tenant_id)

    with {:ok, updated} <- Tenants.update_tenant(tenant, tenant_params) do
      json(conn, %{data: format_tenant(updated)})
    end
  end

  def settings(conn, _params) do
    scope = conn.assigns[:current_scope]

    settings =
      Repo.get_by(TenantSettings, tenant_id: scope.tenant_id) ||
        %TenantSettings{tenant_id: scope.tenant_id}

    json(conn, %{data: format_settings(settings)})
  end

  def update_settings(conn, %{"settings" => settings_params}) do
    scope = conn.assigns[:current_scope]

    existing =
      Repo.get_by(TenantSettings, tenant_id: scope.tenant_id) ||
        %TenantSettings{tenant_id: scope.tenant_id}

    changeset = TenantSettings.changeset(existing, settings_params)

    with {:ok, settings} <- Repo.insert_or_update(changeset) do
      json(conn, %{data: format_settings(settings)})
    end
  end

  defp format_tenant(tenant) do
    %{
      id: tenant.id,
      name: tenant.name,
      slug: tenant.slug,
      inserted_at: tenant.inserted_at,
      updated_at: tenant.updated_at
    }
  end

  defp format_settings(settings) do
    %{
      max_concurrent_experiments: settings.max_concurrent_experiments,
      max_traffic_percentage: settings.max_traffic_percentage,
      default_analysis_method: settings.default_analysis_method,
      default_confidence_level: settings.default_confidence_level,
      data_retention_days: settings.data_retention_days,
      enable_bayesian: settings.enable_bayesian,
      enable_sequential: settings.enable_sequential,
      enable_feature_flags: settings.enable_feature_flags
    }
  end
end
