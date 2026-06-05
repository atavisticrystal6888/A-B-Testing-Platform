defmodule ExperimentHubWeb.ResultsController do
  @moduledoc """
  Serves experiment analysis results to the dashboard.
  Reads persisted analyses when available and returns a stable pending payload
  when no results have been computed yet.
  """
  use ExperimentHubWeb, :controller

  import Ecto.Query

  action_fallback ExperimentHubWeb.FallbackController

  alias Decimal, as: DecimalValue
  alias ExperimentHub.{Experiments, Repo}
  alias ExperimentHub.Metrics.StatisticalAnalysis

  @doc """
  GET /api/v1/experiments/:experiment_id/results
  """
  def show(conn, %{"experiment_id" => experiment_id}) do
    case Experiments.get_experiment(experiment_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        conn
        |> put_status(200)
        |> json(fetch_results(experiment) |> transform_results())
    end
  end

  @doc """
  POST /api/v1/experiments/:experiment_id/analyze
  Trigger analysis on demand.
  """
  def analyze(conn, %{"experiment_id" => experiment_id}) do
    case Experiments.get_experiment(experiment_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        case Experiments.schedule_analysis(experiment) do
          {:ok, _job} ->
            conn
            |> put_status(202)
            |> json(%{status: "accepted", message: "Analysis scheduled"})

          {:error, :disabled} ->
            conn
            |> put_status(503)
            |> json(%{
              error: "service_unavailable",
              message: "Analysis queue is unavailable until Oban is running"
            })

          {:error, reason} ->
            conn
            |> put_status(503)
            |> json(%{
              error: "service_unavailable",
              message: "Failed to schedule analysis: #{inspect(reason)}"
            })
        end
    end
  end

  defp fetch_results(experiment) do
    case persisted_results(experiment) do
      nil -> pending_results(experiment)
      results -> results
    end
  end

  defp persisted_results(experiment) do
    analyses =
      from(sa in StatisticalAnalysis,
        where: sa.experiment_id == ^experiment.id,
        order_by: [desc: sa.computed_at]
      )
      |> Repo.all()

    case analyses do
      [] ->
        nil

      _ ->
        latest_analyses =
          analyses
          |> Enum.group_by(& &1.metric_definition_id)
          |> Map.new(fn {metric_definition_id, [latest | _]} ->
            {metric_definition_id, latest}
          end)

        metrics =
          experiment.experiment_metrics
          |> Enum.map(&build_metric_result(&1, latest_analyses))
          |> Enum.reject(&is_nil/1)

        latest_computed_at = analyses |> hd() |> Map.get(:computed_at)
        overall_status = overall_status(metrics)

        %{
          "experiment_id" => experiment.id,
          "computed_at" => latest_computed_at && DateTime.to_iso8601(latest_computed_at),
          "computation_time_ms" => 0,
          "metrics" => metrics,
          "overall_status" => overall_status,
          "guardrail_breaches" => guardrail_breaches(metrics)
        }
    end
  end

  defp pending_results(experiment) do
    %{
      "experiment_id" => experiment.id,
      "computed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "computation_time_ms" => 0,
      "metrics" => [],
      "overall_status" => "pending",
      "guardrail_breaches" => []
    }
  end

  defp build_metric_result(experiment_metric, latest_analyses) do
    case Map.get(latest_analyses, experiment_metric.metric_definition_id) do
      nil ->
        nil

      analysis ->
        metric =
          analysis
          |> normalized_metric_result(experiment_metric)
          |> ensure_variant_stats(analysis.sample_sizes)

        case metric["guardrail_status"] || build_guardrail_status(experiment_metric, metric) do
          nil -> metric
          guardrail_status -> Map.put(metric, "guardrail_status", guardrail_status)
        end
    end
  end

  defp normalized_metric_result(analysis, experiment_metric) do
    if legacy_metric_payload?(analysis.results) do
      %{
        "metric_key" => experiment_metric.metric_definition.key,
        "metric_type" => experiment_metric.metric_definition.metric_type,
        "role" => experiment_metric.role,
        "frequentist" => analysis.results,
        "variants" => []
      }
    else
      analysis.results
      |> Map.put_new("metric_key", experiment_metric.metric_definition.key)
      |> Map.put_new("metric_type", experiment_metric.metric_definition.metric_type)
      |> Map.put_new("role", experiment_metric.role)
    end
  end

  defp legacy_metric_payload?(results) when is_map(results) do
    is_nil(results["frequentist"]) and not is_nil(results["p_value"])
  end

  defp legacy_metric_payload?(_results), do: false

  defp ensure_variant_stats(metric, sample_sizes) do
    case metric["variants"] do
      variants when is_list(variants) and variants != [] ->
        metric

      _ ->
        Map.put(metric, "variants", build_variant_stats(sample_sizes))
    end
  end

  defp build_variant_stats(sample_sizes) when is_map(sample_sizes) do
    sample_sizes
    |> Enum.sort_by(fn {variant_key, _sample_size} -> variant_key end)
    |> Enum.map(fn {variant_key, sample_size} ->
      %{
        "variant_key" => variant_key,
        "sample_size" => sample_size
      }
    end)
  end

  defp build_variant_stats(_sample_sizes), do: []

  defp build_guardrail_status(experiment_metric, results) do
    with "guardrail" <- experiment_metric.role,
         %DecimalValue{} = threshold <- experiment_metric.guardrail_threshold,
         direction when is_binary(direction) <- experiment_metric.guardrail_direction,
         effect when is_number(effect) <- guardrail_effect(results) do
      threshold_value = DecimalValue.to_float(threshold)
      breached = guardrail_breached?(direction, effect, threshold_value)

      %{
        "threshold" => threshold_value,
        "direction" => direction,
        "current_value" => effect,
        "is_breached" => breached
      }
    else
      _ -> nil
    end
  end

  defp guardrail_effect(results) do
    get_in(results, ["guardrail_status", "current_value"]) ||
      get_in(results, ["frequentist", "effect_size", "relative"]) ||
      get_in(results, ["effect_size", "relative"])
  end

  defp guardrail_breaches(metrics) do
    metrics
    |> Enum.filter(fn metric -> get_in(metric, ["guardrail_status", "is_breached"]) == true end)
    |> Enum.map(& &1["metric_key"])
  end

  defp overall_status([]), do: "pending"

  defp overall_status(metrics) do
    if Enum.any?(metrics, &metric_has_sufficient_data?/1) do
      "sufficient_data"
    else
      "insufficient_data"
    end
  end

  defp metric_has_sufficient_data?(metric) do
    case get_in(metric, ["sample_size_calculation", "is_sufficient"]) do
      true -> true
      false -> false
      nil -> true
    end
  end

  defp guardrail_breached?("below", effect, threshold), do: effect < -threshold
  defp guardrail_breached?("above", effect, threshold), do: effect > threshold
  defp guardrail_breached?("both", effect, threshold), do: abs(effect) > threshold
  defp guardrail_breached?(_direction, _effect, _threshold), do: false

  defp transform_results(results) do
    overall_status = results["overall_status"] || "unknown"

    results
    |> Map.put("has_sufficient_data", overall_status == "sufficient_data")
    |> Map.put("guardrail_breaches", results["guardrail_breaches"] || [])
  end
end
