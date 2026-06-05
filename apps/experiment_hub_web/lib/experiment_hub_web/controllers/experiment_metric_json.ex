defmodule ExperimentHubWeb.ExperimentMetricJSON do
  @moduledoc """
  JSON rendering for experiment metric responses.
  """

  def index(%{experiment_metrics: experiment_metrics}) do
    %{data: Enum.map(experiment_metrics, &experiment_metric_data/1)}
  end

  def show(%{experiment_metric: experiment_metric}) do
    experiment_metric_data(experiment_metric)
  end

  defp experiment_metric_data(em) do
    metric_def = em.metric_definition

    %{
      id: em.id,
      experiment_id: em.experiment_id,
      metric_definition_id: em.metric_definition_id,
      key: metric_def && metric_def.key,
      name: metric_def && metric_def.name,
      role: em.role,
      guardrail_threshold: em.guardrail_threshold,
      guardrail_direction: em.guardrail_direction,
      inserted_at: em.inserted_at
    }
  end
end
