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
    Enum.each(events, &produce_event/1)
  end

  defp produce(topic, key, value) do
    case Application.get_env(:event_collector, :kafka_producer) do
      nil ->
        # Try the Kafka client directly
        EventCollector.Kafka.Client.produce(topic, key, value)

      module ->
        module.produce(topic, key, value)
    end
  end
end
