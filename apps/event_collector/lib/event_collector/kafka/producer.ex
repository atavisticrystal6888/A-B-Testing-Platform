defmodule EventCollector.Kafka.Producer do
  @moduledoc """
  Kafka producer for writing validated events to `experimenthub.events.raw` topic.
  """

  require Logger

  @topic "experimenthub.events.raw"

  @doc """
  Produce a validated event to the events.raw Kafka topic.
  """
  def produce_event(event) when is_map(event) do
    partition_key = "#{event["tenant_id"]}:#{event["experiment_id"]}"
    value = Jason.encode!(event)

    produce(@topic, partition_key, value)
  end

  @doc """
  Produce a batch of validated events.
  """
  def produce_batch(events) when is_list(events) do
    Enum.reduce_while(events, :ok, fn event, :ok ->
      case produce_event(event) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp produce(topic, key, value) do
    case Application.get_env(:event_collector, :kafka_producer) do
      nil ->
        # Try the Kafka client directly
        EventCollector.Kafka.Client.produce(topic, key, value)

      module ->
        module.produce(topic, key, value)
    end
    |> normalize_result()
  end

  defp normalize_result(:ok), do: :ok
  defp normalize_result({:ok, _metadata}), do: :ok
  defp normalize_result({:error, _reason} = error), do: error
  defp normalize_result(other), do: {:error, {:unexpected_result, other}}
end
