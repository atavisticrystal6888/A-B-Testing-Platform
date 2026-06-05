defmodule EventCollector.Kafka.Client do
  @moduledoc """
  Kafka client connection for producer use via :brod.
  Deferred until Broadway/Kafka dependencies are available.
  """

  def child_spec(_opts) do
    # Will be implemented when broadway_kafka dep is resolved
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker
    }
  end

  def start_link(_opts) do
    # Placeholder — actual brod client start deferred until Kafka deps available
    :ignore
  end

  def produce(topic, partition_key, message) when is_binary(topic) do
    case Application.get_env(:event_collector, :kafka_producer) do
      module when is_atom(module) ->
        if function_exported?(module, :produce, 3) do
          module.produce(topic, partition_key, message)
        else
          {:error, :not_configured}
        end

      _ ->
        {:error, :not_configured}
    end
  end
end
