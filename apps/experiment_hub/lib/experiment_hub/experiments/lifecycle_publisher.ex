defmodule ExperimentHub.Experiments.LifecyclePublisher do
  @moduledoc """
  Publishes experiment lifecycle events to Kafka topic `experimenthub.lifecycle` (FR-171).
  """

  @topic "experimenthub.lifecycle"

  @doc """
  Publish a lifecycle event when experiment state changes.
  """
  def publish(experiment, action, opts \\ []) do
    event = %{
      schema_version: 1,
      experiment_id: experiment.id,
      experiment_key: experiment.key,
      tenant_id: experiment.tenant_id,
      action: action,
      status: experiment.status,
      actor_type: Keyword.get(opts, :actor_type, "user"),
      actor_id: Keyword.get(opts, :actor_id),
      metadata: Keyword.get(opts, :metadata, %{}),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish_to_kafka(event)
  end

  defp publish_to_kafka(event) do
    partition_key = event.experiment_id
    encoded = Jason.encode!(event)

    case Application.get_env(:experiment_hub, :kafka_producer) do
      nil ->
        :ok

      producer_module ->
        case producer_module.produce(@topic, partition_key, encoded) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
          _ -> :ok
        end
    end
  end
end
