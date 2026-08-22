defmodule ExperimentHub.Workers.DataRetentionWorkerTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Repo
  alias ExperimentHub.Tenants.TenantSettings
  alias ExperimentHub.Workers.DataRetentionWorker

  defp insert_tenant_settings!(tenant, retention_days) do
    {:ok, settings} =
      %TenantSettings{}
      |> TenantSettings.changeset(%{
        "tenant_id" => tenant.id,
        "data_retention_days" => retention_days
      })
      |> Repo.insert()

    settings
  end

  # `s.tenant_id` on a loaded %TenantSettings{} is Ecto's 36-char string
  # form of the :binary_id column. perform/1 hands it straight to
  # Repo.query!/2 as a raw SQL param compared against `tenant_id uuid` --
  # Postgrex's uuid extension expects the 16-byte binary encoding, not that
  # string, so this exercises the real code path (not a mock) to confirm
  # the fix (Ecto.UUID.dump!/1) rather than merely asserting it in the
  # abstract.
  test "purges rows older than the tenant's retention window without raising on the uuid param" do
    tenant = tenant_fixture()
    # A 1-day retention window keeps both fixture rows inside the current
    # month's partition (experiment_events_raw is partitioned by range on
    # inserted_at, and only the current month's partition exists in a fresh
    # test database) while still landing clearly on either side of the
    # cutoff.
    insert_tenant_settings!(tenant, 1)

    old_cutoff_ts = DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)
    recent_ts = DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)

    old_event_id = Ecto.UUID.generate()
    recent_event_id = Ecto.UUID.generate()
    experiment_id = Ecto.UUID.generate()
    variant_id = Ecto.UUID.generate()

    insert_raw_event!(old_event_id, tenant.id, experiment_id, variant_id, old_cutoff_ts)
    insert_raw_event!(recent_event_id, tenant.id, experiment_id, variant_id, recent_ts)

    assert :ok = DataRetentionWorker.perform(%Oban.Job{})

    remaining_ids =
      Repo.query!("SELECT id FROM experiment_events_raw WHERE tenant_id = $1", [
        Ecto.UUID.dump!(tenant.id)
      ]).rows
      |> Enum.map(fn [id] -> Ecto.UUID.load!(id) end)

    refute old_event_id in remaining_ids
    assert recent_event_id in remaining_ids
  end

  defp insert_raw_event!(id, tenant_id, experiment_id, variant_id, inserted_at) do
    Repo.query!(
      """
      INSERT INTO experiment_events_raw
        (id, tenant_id, experiment_id, variant_id, user_id, event_type, event_name,
         idempotency_key, timestamp, inserted_at)
      VALUES ($1, $2, $3, $4, $5, 'conversion', 'signup', $6, $7, $7)
      """,
      [
        Ecto.UUID.dump!(id),
        Ecto.UUID.dump!(tenant_id),
        Ecto.UUID.dump!(experiment_id),
        Ecto.UUID.dump!(variant_id),
        "user-#{System.unique_integer([:positive])}",
        "idem-#{System.unique_integer([:positive])}",
        inserted_at
      ]
    )
  end
end
