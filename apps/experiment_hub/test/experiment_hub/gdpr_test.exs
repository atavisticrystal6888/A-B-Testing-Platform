defmodule ExperimentHub.GDPRTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.GDPR
  alias ExperimentHub.Repo

  describe "export_user_data/2" do
    test "exports data structure with correct fields" do
      tenant_id = Ecto.UUID.generate()
      user_id = "user_123"

      data = GDPR.export_user_data(tenant_id, user_id)

      assert data.user_id == user_id
      assert data.tenant_id == tenant_id
      assert is_list(data.assignments)
      assert is_binary(data.exported_at)
    end
  end

  describe "erase_user_data/2" do
    # tenant_id is handed to a raw SQL UPDATE (Repo.query!) as a param
    # compared against experiment_events_raw.tenant_id, a `uuid` column.
    # Ecto's :binary_id loads as a 36-char string, but Postgrex's uuid
    # extension for a raw (non-Ecto-typed) query expects the 16-byte binary
    # encoding -- exercising the real code path (not asserting the
    # conversion in isolation) is what would have caught this.
    test "anonymizes assignments and raw events without raising on the uuid param" do
      tenant = tenant_fixture()
      experiment = experiment_fixture(%{tenant: tenant})
      variant = variant_fixture(%{experiment: experiment, tenant: tenant})
      user_id = "user-to-forget"

      {:ok, assignment} =
        %ExperimentHub.Assignments.Assignment{}
        |> ExperimentHub.Assignments.Assignment.changeset(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "variant_id" => variant.id,
          "user_id" => user_id,
          "assigned_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert()

      insert_raw_event!(tenant.id, experiment.id, variant.id, user_id)

      assert {:ok, result} = GDPR.erase_user_data(tenant.id, user_id)
      assert result.user_id == user_id
      assert is_binary(result.anonymized_to)

      reloaded = Repo.get!(ExperimentHub.Assignments.Assignment, assignment.id)
      assert reloaded.user_id == result.anonymized_to

      %{rows: rows} =
        Repo.query!(
          "SELECT user_id, properties FROM experiment_events_raw WHERE tenant_id = $1",
          [
            Ecto.UUID.dump!(tenant.id)
          ]
        )

      assert [[anonymized_user_id, %{}]] = rows
      assert anonymized_user_id == result.anonymized_to
    end

    defp insert_raw_event!(tenant_id, experiment_id, variant_id, user_id) do
      Repo.query!(
        """
        INSERT INTO experiment_events_raw
          (id, tenant_id, experiment_id, variant_id, user_id, event_type, event_name,
           properties, idempotency_key, timestamp, inserted_at)
        VALUES ($1, $2, $3, $4, $5, 'conversion', 'signup', '{"ip": "1.2.3.4"}'::jsonb, $6, now(), now())
        """,
        [
          Ecto.UUID.dump!(Ecto.UUID.generate()),
          Ecto.UUID.dump!(tenant_id),
          Ecto.UUID.dump!(experiment_id),
          Ecto.UUID.dump!(variant_id),
          user_id,
          "idem-#{System.unique_integer([:positive])}"
        ]
      )
    end
  end
end
