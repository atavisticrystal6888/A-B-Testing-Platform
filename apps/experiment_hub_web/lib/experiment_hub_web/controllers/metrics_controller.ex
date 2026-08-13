defmodule ExperimentHubWeb.MetricsController do
  @moduledoc """
  Exposes application metrics in Prometheus text exposition format (Article IX).

  Served unauthenticated on `GET /metrics` — it is scraped by infrastructure
  (Prometheus) and is intentionally outside the API auth pipelines.
  """
  use ExperimentHubWeb, :controller

  def index(conn, _params) do
    body = TelemetryMetricsPrometheus.Core.scrape()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end
end
