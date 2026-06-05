defmodule ExperimentHub.Workers.PartitionManagerWorker do
  @moduledoc """
  Oban worker for automatic monthly partition creation (FR-303).
  Creates partitions for experiment_events_raw, experiment_results_daily, and audit_logs.
  """
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  alias ExperimentHub.Repo

  @partitioned_tables ~w(experiment_events_raw experiment_results_daily audit_logs)

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = Date.utc_today()
    # Create partitions for next 2 months
    months = [
      now,
      Date.add(now, 31),
      Date.add(now, 62)
    ]

    Enum.each(@partitioned_tables, fn table ->
      Enum.each(months, fn date ->
        create_monthly_partition(table, date)
      end)
    end)

    :ok
  end

  defp create_monthly_partition(table, date) do
    year = date.year
    month = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    partition_name = "#{table}_#{year}_#{month}"

    start_date = Date.new!(year, date.month, 1)

    end_date =
      start_date
      |> Date.add(31)
      |> then(fn d -> Date.new!(d.year, d.month, 1) end)

    sql = """
    CREATE TABLE IF NOT EXISTS #{partition_name}
    PARTITION OF #{table}
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """

    case Repo.query(sql) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end
end
