defmodule ExperimentHub.Metrics.GuardrailEvaluator do
  @moduledoc """
  Evaluates guardrail metrics to detect degradation (FR-095).
  Checks if metric values breach configured thresholds.
  """

  alias ExperimentHub.{Repo, Metrics}
  import Ecto.Query

  @doc """
  Evaluate all guardrail metrics for an experiment.
  Returns list of {metric_id, :ok | :breach, details}.
  """
  def evaluate(experiment_id) do
    guardrails =
      Metrics.list_experiment_metrics(experiment_id)
      |> Enum.filter(fn em -> em.role == "guardrail" end)

    Enum.map(guardrails, fn em ->
      result = evaluate_guardrail(experiment_id, em)
      {em.metric_definition_id, result}
    end)
  end

  defp evaluate_guardrail(experiment_id, experiment_metric) do
    threshold =
      experiment_metric.guardrail_threshold &&
        Decimal.to_float(experiment_metric.guardrail_threshold)

    direction = experiment_metric.guardrail_direction || "below"

    # Get latest analysis results
    case get_latest_result(experiment_id, experiment_metric.metric_definition_id) do
      nil ->
        {:ok, %{message: "no data yet"}}

      result ->
        check_breach(result, threshold, direction)
    end
  end

  defp get_latest_result(experiment_id, metric_definition_id) do
    from(sa in ExperimentHub.Metrics.StatisticalAnalysis,
      where: sa.experiment_id == ^experiment_id,
      order_by: [desc: sa.inserted_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil ->
        nil

      analysis ->
        metrics = analysis.results["metrics"] || []
        Enum.find(metrics, fn m -> m["metric_id"] == metric_definition_id end)
    end
  end

  defp check_breach(result, threshold, direction) when is_number(threshold) do
    effect = get_in(result, ["frequentist", "effect_size", "relative"]) || 0

    breached? =
      case direction do
        "below" -> effect < -threshold
        "above" -> effect > threshold
        "both" -> abs(effect) > threshold
        _ -> false
      end

    if breached? do
      {:breach,
       %{
         effect: effect,
         threshold: threshold,
         direction: direction,
         message: "Guardrail breached: effect #{effect} exceeds threshold #{threshold}"
       }}
    else
      {:ok, %{effect: effect, threshold: threshold}}
    end
  end

  defp check_breach(_result, _threshold, _direction) do
    {:ok, %{message: "no threshold configured"}}
  end

  @doc """
  Check guardrails and return formatted breach list.
  """
  def check_breaches(experiment_id) do
    evaluate(experiment_id)
    |> Enum.filter(fn {_id, {status, _}} -> status == :breach end)
    |> Enum.map(fn {metric_id, {:breach, details}} ->
      %{metric_id: metric_id, details: details}
    end)
  end
end
