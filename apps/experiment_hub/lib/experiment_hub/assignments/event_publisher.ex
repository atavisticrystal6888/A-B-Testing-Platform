defmodule ExperimentHub.Assignments.EventPublisher do
  @moduledoc """
  Publishes assignment events to Kafka topic `experimenthub.assignments`.
  """

  @topic "experimenthub.assignments"

  @doc """
  Publish an assignment event.
  """
  def publish_assignment(assignment_result) do
    event = build_event(assignment_result)
    partition_key = "#{assignment_result.tenant_id}:#{assignment_result.experiment_id}"

    case produce(partition_key, event) do
      :ok ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to publish assignment event: #{inspect(reason)}")
        :ok
    end
  end

  defp build_event(result) do
    %{
      schema_version: 1,
      event_type: "assignment",
      tenant_id: result.tenant_id,
      experiment_id: result.experiment_id,
      experiment_key: result.experiment_key,
      variant_id: result.variant_id,
      variant_key: result.variant_key,
      user_id: result.user_id,
      enrolled: result.enrolled,
      source: result[:source] || "hash",
      assigned_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> Jason.encode!()
  end

  defp produce(key, value) do
    case Application.get_env(:experiment_hub, :kafka_producer) do
      nil -> :ok
      producer_module -> producer_module.produce(@topic, key, value)
    end
  end
end
