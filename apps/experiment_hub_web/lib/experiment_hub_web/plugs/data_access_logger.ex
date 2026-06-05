defmodule ExperimentHubWeb.Plugs.DataAccessLogger do
  @moduledoc """
  GDPR compliance: log all read/write access to PII-containing tables (FR-074).
  """
  import Plug.Conn

  @pii_paths ~w(/api/v1/experiments /v1/events /v1/assign /api/v1/gdpr)

  def init(opts), do: opts

  def call(conn, _opts) do
    if pii_path?(conn.request_path) do
      register_before_send(conn, fn conn ->
        log_access(conn)
        conn
      end)
    else
      conn
    end
  end

  defp pii_path?(path) do
    Enum.any?(@pii_paths, fn prefix -> String.starts_with?(path, prefix) end)
  end

  defp log_access(conn) do
    actor_id = conn.assigns[:current_user_id] || conn.assigns[:api_key_id] || "anonymous"
    tenant_id = conn.assigns[:tenant_id] || "unknown"

    metadata = %{
      type: "data_access",
      actor_id: actor_id,
      tenant_id: tenant_id,
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    require Logger
    Logger.info("DATA_ACCESS: #{Jason.encode!(metadata)}")
  end
end
