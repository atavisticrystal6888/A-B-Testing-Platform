defmodule EventCollector.Kafka.Client do
  @moduledoc """
  Kafka producer client backed by `:brod`.

  Starts a named `:brod` client (`:event_collector_brod`) using the broker
  list from `config :event_collector, :kafka_brokers`. When no brokers are
  configured (the default in test), `start_link/1` returns `:ignore` and
  `produce/3` returns `{:error, :not_configured}` so callers can fall back
  to the disk buffer.

  A `:kafka_producer` application env module, when set, always takes
  precedence over the real client (used by tests to inject fakes).
  """

  require Logger

  @brod_client :event_collector_brod

  @doc "The registered name of the underlying :brod client process."
  def brod_client, do: @brod_client

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  def start_link(_opts) do
    case brokers() do
      [] ->
        :ignore

      brokers ->
        :brod.start_link_client(brokers, @brod_client,
          auto_start_producers: true,
          default_producer_config: [
            required_acks: -1,
            retry_backoff_ms: 500,
            max_retries: 3
          ]
        )
    end
  end

  @doc """
  Produce a message to `topic`, partitioned by hashing `partition_key`.

  Returns `:ok` on acknowledged delivery, `{:error, reason}` otherwise.
  An injected `:kafka_producer` module (application env) takes precedence.
  """
  def produce(topic, partition_key, message) when is_binary(topic) do
    case Application.get_env(:event_collector, :kafka_producer) do
      nil ->
        produce_via_brod(topic, partition_key, message)

      module when is_atom(module) ->
        if function_exported?(module, :produce, 3) do
          module.produce(topic, partition_key, message)
        else
          {:error, :not_configured}
        end

      _other ->
        {:error, :not_configured}
    end
  end

  defp produce_via_brod(topic, partition_key, message) do
    if is_pid(Process.whereis(@brod_client)) do
      with {:ok, partition} <- choose_partition(topic, partition_key) do
        do_produce_sync(topic, partition, partition_key, message)
      end
    else
      {:error, :not_configured}
    end
  end

  # Deterministic partitioning: same partition key (tenant:experiment)
  # always lands on the same partition, preserving per-experiment ordering.
  defp choose_partition(topic, partition_key) do
    case :brod.get_partitions_count(@brod_client, topic) do
      {:ok, count} when count > 0 -> {:ok, :erlang.phash2(partition_key, count)}
      {:ok, _} -> {:error, :no_partitions}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_produce_sync(topic, partition, key, value) do
    case :brod.produce_sync(@brod_client, topic, partition, key, value) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, reason ->
      Logger.warning("Kafka produce_sync exited: #{inspect(reason)}")
      {:error, {:producer_down, reason}}
  end

  defp brokers do
    case Application.get_env(:event_collector, :kafka_brokers) do
      brokers when is_list(brokers) -> brokers
      _ -> []
    end
  end
end
