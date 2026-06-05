defmodule EventCollector.Broadway.EventPipeline do
  @moduledoc """
  Broadway pipeline for inbound event ingestion from `experimenthub.events.inbound` topic.
  Validates, deduplicates, and persists events.
  """

  use Broadway

  alias EventCollector.Broadway.BatchProcessor

  @default_config [
    kafka_brokers: [{"localhost", 9092}],
    kafka_group_id: "experimenthub-event-collector",
    kafka_topics: ["experimenthub.events.inbound"],
    batch_size: 100,
    batch_timeout: 1000,
    concurrency: 4
  ]

  def start_link(opts \\ []) do
    config = Keyword.merge(@default_config, opts)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {
          BroadwayKafka.Producer,
          [
            hosts: config[:kafka_brokers],
            group_id: config[:kafka_group_id],
            topics: config[:kafka_topics],
            receive_interval: 100,
            group_config: [
              offset_commit_interval_seconds: 5,
              rejoin_delay_seconds: 2
            ]
          ]
        },
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: config[:concurrency]
        ]
      ],
      batchers: [
        default: [
          batch_size: config[:batch_size],
          batch_timeout: config[:batch_timeout],
          concurrency: 2
        ]
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _context) do
    case Jason.decode(message.data) do
      {:ok, event} ->
        case EventCollector.Validation.EventValidator.validate(event) do
          {:ok, validated} ->
            Broadway.Message.put_data(message, validated)

          {:error, _errors} ->
            Broadway.Message.failed(message, :validation_error)
        end

      {:error, _} ->
        Broadway.Message.failed(message, :invalid_json)
    end
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, _context) do
    events =
      messages
      |> Enum.filter(&(&1.status == :ok))
      |> Enum.map(& &1.data)

    BatchProcessor.process_batch(events)

    messages
  end

  @impl true
  def handle_failed(messages, _context) do
    require Logger

    Enum.each(messages, fn message ->
      Logger.warning("Event processing failed: #{inspect(message.status)}")
    end)

    messages
  end
end
