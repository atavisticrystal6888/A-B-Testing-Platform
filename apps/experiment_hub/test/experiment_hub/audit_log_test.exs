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
end
