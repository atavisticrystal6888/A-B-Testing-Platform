defmodule ExperimentHubWeb.PowerEstimateController do
  @moduledoc """
  Pre-launch power/sample-size calculator (Roadmap #5).

  Thin proxy to the statistical engine's `POST /stats/v1/power`, augmented
  with a tenant traffic estimate so the dashboard can show "~D days"
  alongside the raw sample size before an experiment is even created.
  """
  use ExperimentHubWeb, :controller

  require Logger

  alias ExperimentHub.Analytics

  @doc """
  POST /api/v1/power-estimate

  Body: `%{"baseline_rate" => float, "mde" => float, "significance_level" =>
  float, "power" => float, "num_variants" => integer}`.

  `mde` (relative minimum detectable effect, as used by the dashboard) is
  translated to the engine's `minimum_detectable_effect` field name — the
  two are not the same key, see statistical_engine/src/models/power.py.
  """
  def create(conn, params) do
    tenant_id = conn.assigns[:current_scope].tenant_id

    engine_request = %{
      baseline_rate: params["baseline_rate"],
      minimum_detectable_effect: params["mde"],
      significance_level: params["significance_level"] || 0.05,
      power: params["power"] || 0.80,
      num_variants: params["num_variants"] || 2
    }

    headers = [
      {"content-type", "application/json"},
      {"x-internal-key", internal_api_key()}
    ]

    req_opts =
      [json: engine_request, headers: headers, receive_timeout: 10_000] ++
        stat_engine_req_options()

    case Req.post("#{stat_engine_url()}/stats/v1/power", req_opts) do
      {:ok, %{status: 200, body: body}} ->
        total_sample_size = body["total_sample_size"]

        conn
        |> put_status(200)
        |> json(%{
          data: %{
            sample_size_per_variant: body["sample_size_per_variant"],
            total_sample_size: total_sample_size,
            estimated_days: estimated_days(total_sample_size, tenant_id)
          }
        })

      {:ok, %{status: status, body: body}} ->
        Logger.error("Power estimate: engine returned #{status}: #{inspect(body)}")
        bad_gateway(conn)

      {:error, reason} ->
        Logger.error("Power estimate: engine unreachable: #{inspect(reason)}")
        bad_gateway(conn)
    end
  end

  defp bad_gateway(conn) do
    conn
    |> put_status(502)
    |> json(%{
      error: "bad_gateway",
      message: "The statistical engine is unavailable right now. Please try again shortly."
    })
  end

  defp estimated_days(total_sample_size, tenant_id) do
    case Analytics.recent_assignment_rate(tenant_id) do
      rate when is_number(rate) and rate > 0 ->
        Kernel.ceil(total_sample_size / rate)

      _ ->
        nil
    end
  end

  defp stat_engine_url do
    Application.get_env(:experiment_hub, :stat_engine_url, "http://localhost:8000")
  end

  defp internal_api_key do
    Application.get_env(:experiment_hub, :stat_engine_api_key, "dev-internal-key")
  end

  defp stat_engine_req_options do
    Application.get_env(:experiment_hub_web, :stat_engine_req_options, [])
  end
end
