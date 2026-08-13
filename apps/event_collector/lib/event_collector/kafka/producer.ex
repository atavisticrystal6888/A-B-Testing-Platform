defmodule EventCollector.Kafka.Producer do
  @moduledoc """
  Kafka producer for writing validated events to `experimenthub.events.raw` topic.

  This is a distinct topic from the pre-validation `KAFKA_TOPICS` env var
  (default `experimenthub.events.inbound`) that Broadway consumes from — see
  the comment above `kafka_topics` in config/runtime.exs. Downstream
  consumers of validated events (e.g. data_pipeline's rollup consumer) should
  read this topic, not the inbound one.
  """

  require Logger

  alias EventCollector.Buffer.DiskBuffer

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
    result =
      case Application.get_env(:event_collector, :kafka_producer) do
        nil ->
          produce_or_buffer(topic, key, value)

        module ->
          module.produce(topic, key, value)
      end

    normalize_result(result)
  end

  defp produce_or_buffer(topic, key, value) do
    case EventCollector.Kafka.Client.produce(topic, key, value) do
      :ok ->
        :ok

      {:error, reason} ->
        buffer_event(topic, key, value, reason)

      other ->
        other
    end
  end

  defp buffer_event(topic, key, value, producer_error) do
    with pid when is_pid(pid) <- Process.whereis(DiskBuffer),
         {:ok, event} <- Jason.decode(value),
         :ok <-
           DiskBuffer.buffer_event(
             event
             |> Map.put("_event_collector_topic", topic)
             |> Map.put("_event_collector_partition_key", key)
           ) do
      Logger.warning("Kafka unavailable; buffered event on disk: #{inspect(producer_error)}")
      :ok
    else
      nil -> {:error, producer_error}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_result(:ok), do: :ok
  defp normalize_result({:ok, _metadata}), do: :ok
  defp normalize_result({:error, _reason} = error), do: error
  defp normalize_result(other), do: {:error, {:unexpected_result, other}}
end
