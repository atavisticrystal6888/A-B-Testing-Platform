defmodule ExperimentHubWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  # Histogram buckets used when exporting duration-style metrics to Prometheus
  # (values are in the metric's declared unit, i.e. milliseconds for durations).
  @prometheus_buckets [1, 2.5, 5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000]

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Prometheus exporter (Article IX): aggregates the metrics below and
      # serves them via GET /metrics (see ExperimentHubWeb.MetricsController).
      {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics()}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Database Metrics
      summary("experiment_hub.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:source]
      ),
      summary("experiment_hub.repo.query.queue_time",
        unit: {:native, :millisecond}
      )
    ]
  end

  @doc """
  The metric definitions above, adapted for the Prometheus exporter.

  `TelemetryMetricsPrometheus.Core` does not support the `summary` metric
  type, so summaries are exported as `distribution` (Prometheus histogram)
  with default buckets. Byte-unit conversions are also unsupported by the
  exporter, so those metrics are exported in plain bytes.
  """
  def prometheus_metrics do
    Enum.map(metrics(), &to_prometheus_metric/1)
  end

  defp to_prometheus_metric(%Telemetry.Metrics.Summary{} = summary) do
    fields =
      summary
      |> Map.from_struct()
      |> Map.update!(:reporter_options, &Keyword.put_new(&1, :buckets, @prometheus_buckets))
      |> Map.update!(:unit, &prometheus_unit/1)

    struct!(Telemetry.Metrics.Distribution, fields)
  end

  defp to_prometheus_metric(metric), do: metric

  # The exporter only understands time conversions; export byte metrics as-is.
  defp prometheus_unit({:byte, _to}), do: :byte
  defp prometheus_unit(unit), do: unit

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {ExperimentHubWeb, :count_users, []}
    ]
  end
end
