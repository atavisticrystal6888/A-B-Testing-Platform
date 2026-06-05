defmodule ExperimentHub.Workers.RetentionWorker do
  @moduledoc """
  Oban worker for 90-day partition retention cleanup (FR-051).
  Drops experiment_events_raw partitions older than 90 days.
  """
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  alias ExperimentHub.Repo

  @retention_days 90

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = Date.utc_today() |> Date.add(-@retention_days)

    # Drop old partitions for raw events
    drop_old_partitions("experiment_events_raw", cutoff)

    :ok
  end

  defp drop_old_partitions(parent_table, cutoff) do
    # List partitions
    {:ok, result} =
      Repo.query(
        """
        SELECT inhrelid::regclass::text AS partition_name
        FROM pg_inherits
        WHERE inhparent = $1::regclass
        ORDER BY inhrelid::regclass::text
        """,
        [parent_table]
      )

    Enum.each(result.rows, fn [partition_name] ->
      case parse_partition_date(partition_name) do
        {:ok, partition_date} ->
          if Date.compare(partition_date, cutoff) == :lt do
            Repo.query!("DROP TABLE IF EXISTS #{partition_name}")
          end

        :error ->
          :ok
      end
    end)
  end

  defp parse_partition_date(partition_name) do
    case Regex.run(~r/(\d{4})_(\d{2})$/, partition_name) do
      [_, year, month] ->
        {:ok, Date.new!(String.to_integer(year), String.to_integer(month), 1)}

      _ ->
        :error
    end
  end
end
