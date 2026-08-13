defmodule ExperimentHub.Workers.PartitionManagerWorker do
  @moduledoc """
  Oban worker for automatic monthly partition creation (FR-303).
  Creates partitions for experiment_events_raw, experiment_results_daily, and audit_logs.

  RLS note: tenant_isolation policies live on the partitioned PARENT tables
  (see migration 20260401000023). PostgreSQL applies the policies of the table
  named in the query, so all application access — which goes through the parent,
  as the Ecto schemas name the parent tables — is filtered even when the planner
  scans child partitions. New child partitions created here therefore need no
  per-partition ENABLE/POLICY; only direct SQL naming a child partition would
  bypass the parent policy, and nothing in the codebase does that.
  """
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  require Logger

  alias ExperimentHub.Repo

  # audit_logs (migration 20260401000015) is intentionally a plain, non-partitioned table.
  @partitioned_tables ~w(experiment_events_raw experiment_results_daily)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    now = Date.utc_today()
    # Create partitions for next 2 months
    months = [
      now,
      Date.add(now, 31),
      Date.add(now, 62)
    ]

    tables = Map.get(args, "tables", @partitioned_tables)

    Enum.each(tables, fn table ->
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
      {:ok, _} ->
        :ok

      {:error, error} ->
        # Log but do not fail the job: a single bad partition should not
        # block creation of the others or trigger Oban retries.
        Logger.warning(
          "PartitionManagerWorker failed to create partition #{partition_name}: " <>
            format_error(error)
        )

        :ok
    end
  end

  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
