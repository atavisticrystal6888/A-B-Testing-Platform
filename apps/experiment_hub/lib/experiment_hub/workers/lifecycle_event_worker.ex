defmodule ExperimentHub.Workers.LifecycleEventWorker do
  @moduledoc """
  Oban worker that publishes experiment lifecycle events to Kafka (FR-070).
  """
  use Oban.Worker,
    queue: :events,
    max_attempts: 5

  @topic "experimenthub.experiments.lifecycle"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event, "experiment_id" => experiment_id} = args}) do
    payload = %{
      event: event,
      experiment_id: experiment_id,
      tenant_id: args["tenant_id"],
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: args["data"] || %{}
    }

    case produce_event(payload) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp produce_event(payload) do
    case Application.get_env(:experiment_hub, :kafka_producer) do
      nil ->
        :ok

      producer ->
        try do
          producer.produce(@topic, Jason.encode!(payload))
        rescue
          _ -> :ok
        end
    end
  end

  @doc """
  Enqueue a lifecycle event.
  """
  def enqueue(event, experiment, data \\ %{}) do
    %{
      event: event,
      experiment_id: experiment.id,
      tenant_id: experiment.tenant_id,
      data: data
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
