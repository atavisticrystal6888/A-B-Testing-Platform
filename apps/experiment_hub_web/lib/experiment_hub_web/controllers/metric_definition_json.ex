defmodule ExperimentHubWeb.MetricDefinitionJSON do
  @moduledoc """
  JSON rendering for metric definition responses.
  """

  def index(%{metric_definitions: metric_definitions}) do
    %{data: Enum.map(metric_definitions, &metric_definition_data/1)}
  end

  def show(%{metric_definition: metric_definition}) do
    metric_definition_data(metric_definition)
  end

  defp metric_definition_data(metric_def) do
    %{
      id: metric_def.id,
      key: metric_def.key,
      name: metric_def.name,
      description: metric_def.description,
      metric_type: metric_def.metric_type,
      definition: metric_def.definition,
      inserted_at: metric_def.inserted_at,
      updated_at: metric_def.updated_at
    }
  end
end
