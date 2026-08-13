defmodule ExperimentHub.Workers.PartitionManagerWorkerTest do
  use ExperimentHub.DataCase, async: false
  use Oban.Testing, repo: ExperimentHub.Repo

  import ExUnit.CaptureLog

  alias ExperimentHub.Workers.PartitionManagerWorker

  defp partition_name(table, date) do
    month = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{table}_#{date.year}_#{month}"
  end

  defp table_exists?(name) do
    %{rows: [[exists]]} =
      Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["public.#{name}"])

    exists
  end

  test "creates partitions for the partitioned tables and returns :ok" do
    assert :ok = perform_job(PartitionManagerWorker, %{})

    now = Date.utc_today()

    for table <- ~w(experiment_events_raw experiment_results_daily),
        date <- [now, Date.add(now, 31), Date.add(now, 62)] do
      name = partition_name(table, date)
      assert table_exists?(name), "expected partition #{name} to exist"
    end
  end

  test "does not attempt partitions for audit_logs (plain, non-partitioned table)" do
    log =
      capture_log(fn ->
        assert :ok = perform_job(PartitionManagerWorker, %{})
      end)

    refute log =~ "audit_logs"
    refute table_exists?(partition_name("audit_logs", Date.utc_today()))
  end

  test "logs a warning instead of swallowing partition-creation errors, still returns :ok" do
    # audit_logs is a plain table, so "CREATE TABLE ... PARTITION OF audit_logs"
    # fails — the worker must log it at warning level and keep :ok semantics.
    log =
      capture_log(fn ->
        assert :ok = perform_job(PartitionManagerWorker, %{"tables" => ["audit_logs"]})
      end)

    assert log =~ "[warning]"
    assert log =~ "PartitionManagerWorker failed to create partition audit_logs_"
  end
end
