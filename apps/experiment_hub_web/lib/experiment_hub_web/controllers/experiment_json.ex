defmodule ExperimentHubWeb.ExperimentJSON do
  @moduledoc """
  JSON rendering for experiment responses.
  """

  alias ExperimentHub.Experiments.Experiment

  def index(%{experiments: experiments, meta: meta}) do
    %{
      data: Enum.map(experiments, &experiment_summary/1),
      meta: meta
    }
  end

  def show(%{experiment: experiment}) do
    experiment_detail(experiment)
  end

  def show_with_warnings(%{experiment: experiment, warnings: warnings}) do
    experiment_detail(experiment)
    |> Map.put(:warnings, warnings)
  end

  def transition(%{experiment: experiment}) do
    %{
      id: experiment.id,
      status: experiment.status,
      started_at: experiment.started_at,
      concluded_at: experiment.concluded_at,
      conclusion_decision: experiment.conclusion_decision,
      version: experiment.version
    }
  end

  defp experiment_summary(experiment) do
    %{
      id: experiment.id,
      key: experiment.key,
      name: experiment.name,
      status: experiment.status,
      feature_tag: experiment.feature_tag,
      variant_count: length(loaded_list(experiment.variants)),
      started_at: experiment.started_at,
      inserted_at: experiment.inserted_at
    }
  end

  defp experiment_detail(%Experiment{} = experiment) do
    %{
      id: experiment.id,
      key: experiment.key,
      name: experiment.name,
      hypothesis: experiment.hypothesis,
      description: experiment.description,
      feature_tag: experiment.feature_tag,
      status: experiment.status,
      variants: Enum.map(loaded_list(experiment.variants), &variant_data/1),
      metrics: Enum.map(loaded_list(experiment.experiment_metrics), &metric_data/1),
      experiment_group_id: experiment.experiment_group_id,
      conclusion_decision: experiment.conclusion_decision,
      conclusion_rationale: experiment.conclusion_rationale,
      scheduled_start_at: experiment.scheduled_start_at,
      scheduled_end_at: experiment.scheduled_end_at,
      started_at: experiment.started_at,
      concluded_at: experiment.concluded_at,
      archived: experiment.archived,
      version: experiment.version,
      inserted_at: experiment.inserted_at,
      updated_at: experiment.updated_at
    }
  end

  defp variant_data(variant) do
    %{
      id: variant.id,
      key: variant.key,
      name: variant.name,
      description: variant.description,
      is_control: variant.is_control,
      traffic_allocation: variant.traffic_allocation,
      sort_order: variant.sort_order
    }
  end

  defp metric_data(experiment_metric) do
    metric_def = loaded_assoc(experiment_metric.metric_definition)

    %{
      id: experiment_metric.id,
      key: metric_def && metric_def.key,
      name: metric_def && metric_def.name,
      metric_type: metric_def && metric_def.metric_type,
      role: experiment_metric.role,
      guardrail_threshold: experiment_metric.guardrail_threshold,
      guardrail_direction: experiment_metric.guardrail_direction
    }
  end

  defp loaded_list(%Ecto.Association.NotLoaded{}), do: []
  defp loaded_list(nil), do: []
  defp loaded_list(list) when is_list(list), do: list

  defp loaded_assoc(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded_assoc(value), do: value
end
