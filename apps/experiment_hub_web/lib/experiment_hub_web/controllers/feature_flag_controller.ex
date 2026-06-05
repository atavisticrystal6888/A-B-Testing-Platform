defmodule ExperimentHubWeb.FeatureFlagController do
  @moduledoc """
  REST API for feature flags (FR-125).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.FeatureFlags

  action_fallback ExperimentHubWeb.FallbackController

  def index(conn, params) do
    tenant_id = conn.assigns[:current_scope].tenant_id
    flags = FeatureFlags.list_flags(tenant_id, status: params["status"])
    json(conn, %{data: Enum.map(flags, &format_flag/1)})
  end

  def show(conn, %{"id" => id}) do
    flag = FeatureFlags.get_flag!(id)
    json(conn, %{data: format_flag(flag)})
  end

  def create(conn, %{"flag" => flag_params}) do
    tenant_id = conn.assigns[:current_scope].tenant_id
    attrs = Map.put(flag_params, "tenant_id", tenant_id)

    with {:ok, flag} <- FeatureFlags.create_flag(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: format_flag(flag)})
    end
  end

  def update(conn, %{"id" => id, "flag" => flag_params}) do
    flag = FeatureFlags.get_flag!(id)

    with {:ok, updated} <- FeatureFlags.update_flag(flag, flag_params) do
      json(conn, %{data: format_flag(updated)})
    end
  end

  def delete(conn, %{"id" => id}) do
    flag = FeatureFlags.get_flag!(id)

    with {:ok, _} <- FeatureFlags.delete_flag(flag) do
      send_resp(conn, :no_content, "")
    end
  end

  def evaluate(conn, %{"key" => key} = params) do
    tenant_id = conn.assigns[:current_scope].tenant_id
    context = params["context"] || %{}

    case FeatureFlags.evaluate(tenant_id, key, context) do
      {:ok, value} ->
        json(conn, %{key: key, enabled: value})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})
    end
  end

  def evaluate_batch(conn, %{"keys" => keys} = params) do
    tenant_id = conn.assigns[:current_scope].tenant_id
    context = params["context"] || %{}

    results = FeatureFlags.evaluate_all(tenant_id, keys, context)
    json(conn, %{data: results})
  end

  defp format_flag(flag) do
    %{
      id: flag.id,
      key: flag.key,
      name: flag.name,
      description: flag.description,
      status: flag.status,
      rollout_percentage: flag.rollout_percentage,
      targeting_rules: flag.targeting_rules,
      inserted_at: flag.inserted_at,
      updated_at: flag.updated_at
    }
  end
end
