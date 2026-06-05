defmodule EventCollector.Buffer.DiskBuffer do
  @moduledoc """
  Disk-backed event buffer for Kafka unavailability (T345).
  Buffers events to local disk when Kafka is unreachable, replays on recovery.
  """
  use GenServer

  @default_max_size 1_073_741_824
  # Retry interval for replaying buffered events
  @retry_interval_ms 5_000
  _ = @retry_interval_ms

  defstruct [:buffer_dir, :max_size, :current_size, :file_count, :replaying]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def buffer_event(event) do
    GenServer.call(__MODULE__, {:buffer, event})
  end

  def buffer_full? do
    GenServer.call(__MODULE__, :buffer_full?)
  end

  def replay do
    GenServer.cast(__MODULE__, :replay)
  end

  @impl true
  def init(opts) do
    buffer_dir = Keyword.get(opts, :buffer_dir, "tmp/event_buffer")
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    File.mkdir_p!(buffer_dir)

    current_size = calculate_dir_size(buffer_dir)
    file_count = count_files(buffer_dir)

    {:ok,
     %__MODULE__{
       buffer_dir: buffer_dir,
       max_size: max_size,
       current_size: current_size,
       file_count: file_count,
       replaying: false
     }}
  end

  @impl true
  def handle_call({:buffer, event}, _from, state) do
    encoded = Jason.encode!(event)
    event_size = byte_size(encoded)

    if state.current_size + event_size > state.max_size do
      {:reply, {:error, :buffer_full}, state}
    else
      filename = "#{System.monotonic_time()}_#{state.file_count}.json"
      path = Path.join(state.buffer_dir, filename)
      File.write!(path, encoded)

      new_state = %{
        state
        | current_size: state.current_size + event_size,
          file_count: state.file_count + 1
      }

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:buffer_full?, _from, state) do
    {:reply, state.current_size >= state.max_size, state}
  end

  @impl true
  def handle_cast(:replay, %{replaying: true} = state), do: {:noreply, state}

  @impl true
  def handle_cast(:replay, state) do
    send(self(), :do_replay)
    {:noreply, %{state | replaying: true}}
  end

  @impl true
  def handle_info(:do_replay, state) do
    files =
      state.buffer_dir
      |> File.ls!()
      |> Enum.sort()

    Enum.each(files, fn file ->
      path = Path.join(state.buffer_dir, file)

      case File.read(path) do
        {:ok, data} ->
          event = Jason.decode!(data)
          # Attempt to send to Kafka
          case send_to_kafka(event) do
            :ok -> File.rm!(path)
            {:error, _} -> :ok
          end

        _ ->
          :ok
      end
    end)

    new_size = calculate_dir_size(state.buffer_dir)
    {:noreply, %{state | replaying: false, current_size: new_size}}
  end

  defp send_to_kafka(event) do
    topic = Map.get(event, "topic", "experimenthub.events.raw")
    encoded = Jason.encode!(event)

    case EventCollector.Kafka.Client.produce(topic, "", encoded) do
      :ok -> :ok
      {:error, _} = error -> error
      _ -> {:error, :kafka_unavailable}
    end
  end

  defp calculate_dir_size(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.reduce(files, 0, fn file, acc ->
          path = Path.join(dir, file)

          case File.stat(path) do
            {:ok, %{size: size}} -> acc + size
            _ -> acc
          end
        end)

      _ ->
        0
    end
  end

  defp count_files(dir) do
    case File.ls(dir) do
      {:ok, files} -> length(files)
      _ -> 0
    end
  end
end
