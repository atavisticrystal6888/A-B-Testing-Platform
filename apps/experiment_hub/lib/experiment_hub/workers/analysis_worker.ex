defmodule ExperimentHub.Workers.AnalysisWorker do
  @moduledoc """
  Oban worker that triggers statistical analysis via HTTP call to the statistical engine.
  Propagates W3C Trace Context headers (Constitution Art.IX).
  """
  use Oban.Worker, queue: :analysis, max_attempts: 3

  require Logger

  alias ExperimentHub.Repo
  alias ExperimentHub.Experiments
  alias ExperimentHub.Metrics
  alias ExperimentHub.Metrics.StatisticalAnalysis

  @stat_engine_url Application.compile_env(
                     :experiment_hub,
                     :stat_engine_url,
                     "http://localhost:8000"
                   )

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"experiment_id" => experiment_id, "tenant_id" => tenant_id} = args
      }) do
    Repo.put_tenant_id(tenant_id)
    trace_id = args["trace_id"] || generate_trace_id()

    case Experiments.get_experiment(experiment_id) do
      nil ->
        Logger.warning("Analysis worker: experiment #{experiment_id} not found")
        :ok

      experiment ->
        run_analysis(experiment, tenant_id, trace_id)
    end
  end

  defp run_analysis(experiment, tenant_id, trace_id) do
    metrics = Metrics.list_experiment_metrics(experiment.id)
    experiment = Repo.preload(experiment, :variants)

    request_body = %{
      tenant_id: tenant_id,
      experiment_id: experiment.id,
      metrics:
        Enum.map(metrics, fn em ->
          md = em.metric_definition

          %{
            metric_definition_id: md.id,
            metric_key: md.key,
            metric_type: md.metric_type,
            role: em.role,
            guardrail_threshold: em.guardrail_threshold,
            guardrail_direction: em.guardrail_direction
          }
        end),
      variants:
        Enum.map(experiment.variants, fn v ->
          %{
            variant_id: v.id,
            variant_key: v.key,
            is_control: v.is_control
          }
        end),
      config: %{
        significance_level: 0.05,
        power: 0.80,
        sequential_analysis: true,
        spending_function: "obrien_fleming",
        analysis_types: ["frequentist"]
      }
    }

    headers = [
      {"content-type", "application/json"},
      {"x-internal-key", internal_api_key()},
      {"traceparent", "00-#{trace_id}-#{generate_span_id()}-01"}
    ]

    case Req.post("#{stat_engine_url()}/stats/v1/analyze/#{experiment.id}",
           json: request_body,
           headers: headers,
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        store_results(body, experiment, tenant_id, metrics)
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Analysis API returned #{status}: #{inspect(body)}")
        {:error, "Analysis API error: #{status}"}

      {:error, reason} ->
        Logger.error("Analysis API call failed: #{inspect(reason)}")
        {:error, "Analysis API unreachable"}
    end
  end

  defp store_results(body, experiment, tenant_id, metrics) do
    Enum.each(body["metrics"] || [], fn metric_result ->
      case find_metric_id(metric_result["metric_key"], metrics) do
        nil ->
          Logger.warning(
            "Analysis worker: metric #{inspect(metric_result["metric_key"])} is not attached to experiment #{experiment.id}"
          )

        metric_definition_id ->
          case %StatisticalAnalysis{}
               |> StatisticalAnalysis.changeset(%{
                 tenant_id: tenant_id,
                 experiment_id: experiment.id,
                 metric_definition_id: metric_definition_id,
                 analysis_type: metric_analysis_type(metric_result),
                 methodology: metric_methodology(metric_result),
                 parameters: %{significance_level: 0.05},
                 results: metric_result,
                 sample_sizes: extract_sample_sizes(metric_result),
                 is_significant: get_in(metric_result, ["frequentist", "is_significant"]),
                 winning_variant_id: nil
               })
               |> Repo.insert() do
            {:ok, _analysis} ->
              :ok

            {:error, changeset} ->
              Logger.error(
                "Analysis worker: failed to persist results for experiment #{experiment.id}: #{inspect(changeset.errors)}"
              )
          end
      end
    end)
  end

  defp find_metric_id(metric_key, metrics) when is_binary(metric_key) do
    Enum.find_value(metrics, fn experiment_metric ->
      if experiment_metric.metric_definition.key == metric_key do
        experiment_metric.metric_definition_id
      end
    end)
  end

  defp find_metric_id(_metric_key, _metrics), do: nil

  defp extract_sample_sizes(metric_result) do
    (metric_result["variants"] || [])
    |> Enum.into(%{}, fn v ->
      {v["variant_key"], v["sample_size"]}
    end)
  end

  defp metric_analysis_type(%{"bayesian" => bayesian}) when is_map(bayesian), do: "bayesian"

  defp metric_analysis_type(%{"sequential" => sequential}) when is_map(sequential),
    do: "sequential"

  defp metric_analysis_type(_metric_result), do: "frequentist"

  defp metric_methodology(%{"frequentist" => %{"test_method" => test_method}})
       when is_binary(test_method) do
    test_method
  end

  defp metric_methodology(%{"sequential" => _sequential}), do: "sequential_analysis"
  defp metric_methodology(%{"guardrail_status" => _guardrail_status}), do: "guardrail_threshold"
  defp metric_methodology(_metric_result), do: "z_test_proportions"

  defp stat_engine_url do
    Application.get_env(:experiment_hub, :stat_engine_url, @stat_engine_url)
  end

  defp internal_api_key do
    Application.get_env(:experiment_hub, :stat_engine_api_key, "dev-internal-key")
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
