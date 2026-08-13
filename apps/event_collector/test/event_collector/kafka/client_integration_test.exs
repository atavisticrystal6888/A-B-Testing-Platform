defmodule EventCollector.Kafka.ClientIntegrationTest do
  @moduledoc """
  Round-trip integration test against a real Kafka broker.

  Excluded by default (see test_helper.exs). Requires the docker compose
  Kafka broker on localhost:9092:

      docker compose up -d kafka
      mix test --only kafka_integration apps/event_collector
  """

  use ExUnit.Case, async: false

  alias EventCollector.Kafka.Client

  @moduletag :kafka_integration

  @brokers [{"localhost", 9092}]
  @topic "experimenthub.events.raw"

  setup_all do
    # Make sure the topic exists (3 partitions so key-hashing is meaningful).
    topic_spec = %{
      name: @topic,
      num_partitions: 3,
      replication_factor: 1,
      assignments: [],
      configs: []
    }

    case :brod.create_topics(@brokers, [topic_spec], %{timeout: 10_000}) do
      :ok -> :ok
      # Already exists (or racing another run) — fine, later steps fail loudly
      # if the topic is genuinely absent.
      {:error, _} -> :ok
    end

    :ok
  end

  setup do
    original_brokers = Application.get_env(:event_collector, :kafka_brokers)
    original_producer = Application.get_env(:event_collector, :kafka_producer)

    Application.put_env(:event_collector, :kafka_brokers, @brokers)
    Application.delete_env(:event_collector, :kafka_producer)

    # The app supervisor started Client as :ignore (test env has no brokers),
    # so start the brod client manually for this test.
    client_started? = is_pid(Process.whereis(Client.brod_client()))

    unless client_started? do
      assert {:ok, _pid} = Client.start_link([])
    end

    on_exit(fn ->
      # The brod client is linked to the (now dead) test process, so it is
      # usually already gone; stop it only if it survived.
      if not client_started? and is_pid(Process.whereis(Client.brod_client())) do
        :brod.stop_client(Client.brod_client())
      end

      restore_env(:kafka_brokers, original_brokers)
      restore_env(:kafka_producer, original_producer)
    end)

    :ok
  end

  test "produces via the real client and reads the message back" do
    tenant_id = Ecto.UUID.generate()
    experiment_id = Ecto.UUID.generate()
    partition_key = "#{tenant_id}:#{experiment_id}"

    payload =
      Jason.encode!(%{
        "tenant_id" => tenant_id,
        "experiment_id" => experiment_id,
        "user_id" => "kafka-integration-user",
        "event_type" => "conversion",
        "event_name" => "kafka_integration_roundtrip",
        "idempotency_key" => "kafka-integration-#{System.unique_integer([:positive])}"
      })

    # Partition must match the Client's choice so we can fetch it back.
    {:ok, partition_count} = :brod.get_partitions_count(Client.brod_client(), @topic)
    partition = :erlang.phash2(partition_key, partition_count)

    {:ok, before_offset} = resolve_latest_offset(partition)

    assert :ok = Client.produce(@topic, partition_key, payload)

    assert {:ok, messages} = fetch_from(partition, before_offset)

    keys_and_values = Enum.map(messages, fn {_offset, key, value} -> {key, value} end)

    assert {partition_key, payload} in keys_and_values
  end

  test "produce_event goes through Producer to the real broker" do
    event = %{
      "tenant_id" => Ecto.UUID.generate(),
      "experiment_id" => Ecto.UUID.generate(),
      "user_id" => "kafka-integration-user",
      "event_type" => "exposure",
      "event_name" => "kafka_integration_producer",
      "idempotency_key" => "kafka-integration-#{System.unique_integer([:positive])}"
    }

    buffered_before = disk_buffer_file_count()

    assert :ok = EventCollector.Kafka.Producer.produce_event(event)

    # A DiskBuffer fallback would also return :ok — make sure the event
    # really went to Kafka rather than to disk.
    assert disk_buffer_file_count() == buffered_before,
           "event was buffered on disk instead of produced to Kafka"
  end

  defp disk_buffer_file_count do
    case Process.whereis(EventCollector.Buffer.DiskBuffer) do
      nil -> 0
      _pid -> :sys.get_state(EventCollector.Buffer.DiskBuffer).file_count
    end
  end

  # Right after topic creation the single-broker cluster may briefly report
  # :not_leader_for_partition while leadership settles — retry.
  defp resolve_latest_offset(partition, attempts \\ 20)

  defp resolve_latest_offset(partition, attempts) do
    case :brod.resolve_offset(@brokers, @topic, partition, :latest) do
      {:ok, {offset, _}} ->
        {:ok, offset}

      {:ok, offset} when is_integer(offset) ->
        {:ok, offset}

      {:error, _reason} = error ->
        if attempts > 1 do
          Process.sleep(250)
          resolve_latest_offset(partition, attempts - 1)
        else
          error
        end
    end
  end

  defp fetch_from(partition, offset, attempts \\ 10)

  defp fetch_from(_partition, _offset, 0), do: {:error, :no_messages}

  defp fetch_from(partition, offset, attempts) do
    case :brod.fetch(@brokers, @topic, partition, offset) do
      {:ok, {_hw_offset, []}} ->
        Process.sleep(200)
        fetch_from(partition, offset, attempts - 1)

      {:ok, {_hw_offset, messages}} ->
        {:ok,
         Enum.map(messages, fn {:kafka_message, offset, key, value, _ts_type, _ts, _headers} ->
           {offset, key, value}
         end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:event_collector, key)
  defp restore_env(key, value), do: Application.put_env(:event_collector, key, value)
end
