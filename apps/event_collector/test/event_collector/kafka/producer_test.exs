defmodule EventCollector.Kafka.ProducerTest do
  use ExUnit.Case, async: false

  alias EventCollector.Buffer.DiskBuffer
  alias EventCollector.Kafka.Producer

  setup do
    original_producer = Application.get_env(:event_collector, :kafka_producer)
    buffer_was_started? = is_pid(Process.whereis(DiskBuffer))

    unless buffer_was_started? do
      start_supervised!({DiskBuffer, buffer_dir: temporary_buffer_dir()})
    end

    buffer_state = :sys.get_state(DiskBuffer)
    File.mkdir_p!(buffer_state.buffer_dir)
    files_before = File.ls!(buffer_state.buffer_dir) |> MapSet.new()

    Application.delete_env(:event_collector, :kafka_producer)

    on_exit(fn ->
      restore_producer(original_producer)

      buffer_state.buffer_dir
      |> File.ls!()
      |> Enum.reject(&MapSet.member?(files_before, &1))
      |> Enum.each(fn file -> File.rm!(Path.join(buffer_state.buffer_dir, file)) end)
    end)

    %{buffer_state: buffer_state}
  end

  test "buffers an event when the default Kafka client is unavailable", %{
    buffer_state: before_state
  } do
    event = %{
      "tenant_id" => Ecto.UUID.generate(),
      "experiment_id" => Ecto.UUID.generate(),
      "user_id" => "buffer-demo-user",
      "event_type" => "conversion",
      "event_name" => "checkout_completed",
      "idempotency_key" => "buffer-demo-event"
    }

    assert :ok = Producer.produce_event(event)

    after_state = :sys.get_state(DiskBuffer)
    assert after_state.file_count == before_state.file_count + 1
    assert after_state.current_size > before_state.current_size
  end

  defp restore_producer(nil), do: Application.delete_env(:event_collector, :kafka_producer)

  defp restore_producer(producer),
    do: Application.put_env(:event_collector, :kafka_producer, producer)

  defp temporary_buffer_dir do
    Path.join(System.tmp_dir!(), "event-collector-producer-#{System.unique_integer([:positive])}")
  end
end
