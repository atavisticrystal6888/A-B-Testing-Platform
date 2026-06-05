defmodule EventCollector.Broadway.BatchProcessor do
  @moduledoc """
  Batch processor for Broadway pipeline.
  Validates, deduplicates (via ON CONFLICT DO NOTHING), and persists events to PostgreSQL.
  """

  require Logger

  alias ExperimentHub.Repo
  alias ExperimentHub.Events.ExperimentEvent

  @doc """
  Process a batch of validated events. Inserts with ON CONFLICT DO NOTHING for deduplication.
  """
  def process_batch(events) when is_list(events) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(events, fn event ->
        %{
          id: Ecto.UUID.generate(),
          tenant_id: event["tenant_id"],
          experiment_id: event["experiment_id"],
          variant_id: event["variant_id"],
          user_id: event["user_id"],
          event_type: event["event_type"],
          event_name: event["event_name"],
          value: event["value"],
          properties: event["properties"] || %{},
          idempotency_key: event["idempotency_key"],
          is_bot: event["is_bot"] || false,
          is_post_conclusion: event["is_post_conclusion"] || false,
          timestamp: parse_timestamp(event["timestamp"]),
          inserted_at: now
        }
      end)

    case insert_batch(entries) do
      {:ok, count} ->
        Logger.debug("Persisted #{count} events")
        {:ok, count}

      {:error, reason} ->
        Logger.error("Batch insert failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp insert_batch([]), do: {:ok, 0}

  defp insert_batch(entries) do
    try do
      {count, _} =
        Repo.insert_all(
          ExperimentEvent,
          entries,
          on_conflict: :nothing,
          conflict_target: [:tenant_id, :idempotency_key]
        )

      {:ok, count}
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end

  defp parse_timestamp(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp parse_timestamp(ts), do: ts
end
