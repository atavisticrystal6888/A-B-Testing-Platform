defmodule ExperimentHubWeb.AuditLogController do
  @moduledoc """
  REST API for querying audit logs (FR-070).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.AuditLog

  def index(conn, %{"experiment_id" => experiment_id} = params) do
    logs =
      AuditLog.list_for_resource("experiment", experiment_id,
        limit: params["limit"] || 50,
        offset: params["offset"] || 0
      )

    json(conn, %{data: Enum.map(logs, &format_log/1)})
  end

  def tenant_index(conn, params) do
    tenant_id = conn.assigns[:current_scope].tenant_id

    logs =
      AuditLog.list_for_tenant(tenant_id,
        limit: params["limit"] || 50,
        offset: params["offset"] || 0
      )

    json(conn, %{data: Enum.map(logs, &format_log/1)})
  end

  defp format_log(log) do
    %{
      id: log.id,
      actor_id: log.actor_id,
      actor_type: log.actor_type,
      action: log.action,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      changes: log.changes,
      reason: log.reason,
      timestamp: log.inserted_at
    }
  end
end
