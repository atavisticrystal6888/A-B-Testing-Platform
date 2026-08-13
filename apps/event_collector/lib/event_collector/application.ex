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

    # Generous restart intensity: brod/Broadway retry broker connections
    # internally, but transient crashes while Kafka is down must not take
    # the whole app down with it.
    opts = [
      strategy: :one_for_one,
      name: EventCollector.Supervisor,
      max_restarts: 10,
      max_seconds: 60
    ]

    Supervisor.start_link(children, opts)
  end

  defp maybe_pipeline_child do
    if Application.get_env(:event_collector, :start_pipeline?, false) and
         Code.ensure_loaded?(BroadwayKafka.Producer) do
      [{EventCollector.Broadway.EventPipeline, []}]
    else
      []
    end
  end
end
