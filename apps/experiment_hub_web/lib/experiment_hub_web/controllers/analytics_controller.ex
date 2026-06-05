defmodule ExperimentHubWeb.AnalyticsController do
  @moduledoc """
  REST API for platform analytics (FR-140).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Analytics

  def overview(conn, _params) do
    tenant_id = conn.assigns[:current_scope].tenant_id
    data = Analytics.overview(tenant_id)
    json(conn, %{data: data})
  end
end
