defmodule ExperimentHub.Workers.DataRetentionWorker do
  @moduledoc """
  Oban worker for data retention policy enforcement (FR-305).
  Removes old raw events and daily results beyond retention period.
  """
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  alias ExperimentHub.Repo
  alias ExperimentHub.Tenants.TenantSettings

  @default_retention_days 365

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    settings = Repo.all(TenantSettings)

    Enum.each(settings, fn s ->
      retention_days = s.data_retention_days || @default_retention_days

      cutoff =
        DateTime.utc_now()
        |> DateTime.add(-retention_days * 86400, :second)
        |> DateTime.truncate(:second)

      # Purge old raw events
      Repo.query!(
        "DELETE FROM experiment_events_raw WHERE tenant_id = $1 AND inserted_at < $2",
        [s.tenant_id, cutoff]
      )

      # Purge old daily results
      Repo.query!(
        "DELETE FROM experiment_results_daily WHERE tenant_id = $1 AND inserted_at < $2",
        [s.tenant_id, cutoff]
      )
    end)

    :ok
  end
end
