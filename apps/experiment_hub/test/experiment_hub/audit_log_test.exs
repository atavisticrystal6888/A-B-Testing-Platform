defmodule ExperimentHub.AuditLogTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.AuditLog

  describe "log/1" do
    test "creates an audit log entry" do
      attrs = %{
        tenant_id: Ecto.UUID.generate(),
        actor_type: "user",
        action: "created",
        resource_type: "experiment",
        resource_id: Ecto.UUID.generate()
      }

      assert {:ok, log} = AuditLog.log(attrs)
      assert log.action == "created"
      assert log.actor_type == "user"
    end

    test "validates required fields" do
      assert {:error, changeset} = AuditLog.log(%{})
      assert errors_on(changeset) |> Map.has_key?(:tenant_id)
      assert errors_on(changeset) |> Map.has_key?(:action)
    end

    test "validates actor_type" do
      attrs = %{
        tenant_id: Ecto.UUID.generate(),
        actor_type: "invalid",
        action: "created",
        resource_type: "experiment",
        resource_id: Ecto.UUID.generate()
      }

      assert {:error, changeset} = AuditLog.log(attrs)
      assert errors_on(changeset) |> Map.has_key?(:actor_type)
    end
  end

  describe "list_for_resource/3 with :actions" do
    test "filters actions in the query, so an old lifecycle row survives a busy resource's row cap" do
      tenant = tenant_fixture()
      experiment = experiment_fixture(tenant: tenant)

      old_lifecycle_at = ~U[2020-01-01 00:00:00.000000Z]
      insert_audit_log!(experiment, "created", old_lifecycle_at)

      # Newer, non-lifecycle rows -- e.g. metric attach/detach noise a busy
      # experiment accumulates between its lifecycle transitions.
      for i <- 1..5 do
        insert_audit_log!(experiment, "metric_attached", DateTime.add(old_lifecycle_at, i, :day))
      end

      # limit: 3 simulates the row cap being smaller than the total row
      # count. Without the :actions filter applied in the query itself, the
      # 5 newer non-lifecycle rows alone fill this cap and the old
      # "created" row is never even fetched for a caller to filter down to.
      result =
        AuditLog.list_for_resource("experiment", experiment.id, limit: 3, actions: ["created"])

      assert Enum.map(result, & &1.action) == ["created"]
    end

    test "an empty or absent :actions leaves existing callers unchanged" do
      tenant = tenant_fixture()
      experiment = experiment_fixture(tenant: tenant)

      insert_audit_log!(experiment, "created", ~U[2020-01-01 00:00:00.000000Z])
      insert_audit_log!(experiment, "metric_attached", ~U[2020-01-02 00:00:00.000000Z])

      without_opt = AuditLog.list_for_resource("experiment", experiment.id, limit: 50)
      with_empty = AuditLog.list_for_resource("experiment", experiment.id, limit: 50, actions: [])

      assert length(without_opt) == 2
      assert Enum.map(without_opt, & &1.id) == Enum.map(with_empty, & &1.id)
    end
  end

  defp insert_audit_log!(experiment, action, inserted_at) do
    %AuditLog{}
    |> Ecto.Changeset.change(%{
      tenant_id: experiment.tenant_id,
      actor_type: "system",
      action: action,
      resource_type: "experiment",
      resource_id: experiment.id,
      inserted_at: inserted_at
    })
    |> Repo.insert!()
  end
end
