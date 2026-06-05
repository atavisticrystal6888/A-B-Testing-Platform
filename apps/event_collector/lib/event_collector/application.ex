defmodule EventCollector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {EventCollector.Buffer.DiskBuffer, []},
        EventCollector.Kafka.Client
      ] ++ maybe_pipeline_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventCollector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_pipeline_child do
    broadway_kafka_producer = Module.concat([BroadwayKafka, Producer])

    if Code.ensure_loaded?(broadway_kafka_producer) do
      [{EventCollector.Broadway.EventPipeline, []}]
    else
      []
    end
  end
end
