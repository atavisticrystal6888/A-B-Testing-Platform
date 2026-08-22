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

      # Ecto loads :binary_id/:uuid columns as their 36-char string form on
      # the struct, but raw SQL via Repo.query!/2 isn't routed through
      # Ecto's type system -- Postgrex infers the $1 placeholder's type from
      # the `tenant_id uuid` column it's compared against and its uuid
      # extension expects the 16-byte binary encoding, not the string form.
      # Without dump!/1 this raises DBConnection.EncodeError before any row
      # is touched.
      tenant_id = Ecto.UUID.dump!(s.tenant_id)

      # Purge old raw events
      Repo.query!(
        "DELETE FROM experiment_events_raw WHERE tenant_id = $1 AND inserted_at < $2",
        [tenant_id, cutoff]
      )

      # Purge old daily results
      Repo.query!(
        "DELETE FROM experiment_results_daily WHERE tenant_id = $1 AND inserted_at < $2",
        [tenant_id, cutoff]
      )
    end)

    :ok
  end
end
