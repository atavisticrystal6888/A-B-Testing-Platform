defmodule ExperimentHub.Assignments.FlipFlopPreventionTest do
  use ExperimentHub.DataCase, async: false
  import ExperimentHub.TestFixtures

  alias ExperimentHub.Assignments.AssignmentPersistence

  setup do
    tenant = tenant_fixture()
    {:ok, tenant: tenant}
  end

  describe "flip-flop prevention" do
    test "persisted assignment is returned on subsequent calls", %{tenant: tenant} do
      experiment = experiment_fixture(%{tenant: tenant})
      variant = variant_fixture(%{tenant: tenant, experiment: experiment})

      # Persist an assignment
      {:ok, _} =
        AssignmentPersistence.persist(%{
          tenant_id: tenant.id,
          experiment_id: experiment.id,
          variant_id: variant.id,
          user_id: "user-flip-1"
        })

      # Should find it
      assert {:ok, assignment} =
               AssignmentPersistence.get_existing(tenant.id, experiment.id, "user-flip-1")

      assert assignment.variant_id == variant.id
    end

    test "no assignment returns not_found", %{tenant: tenant} do
      assert {:error, :not_found} =
               AssignmentPersistence.get_existing(tenant.id, Ecto.UUID.generate(), "nonexistent")
    end

    test "concurrent insert uses ON CONFLICT DO NOTHING", %{tenant: tenant} do
      experiment = experiment_fixture(%{tenant: tenant})

      variant_1 =
        variant_fixture(%{
          tenant: tenant,
          experiment: experiment,
          key: "control",
          name: "Control"
        })

      variant_2 =
        variant_fixture(%{
          tenant: tenant,
          experiment: experiment,
          key: "treatment",
          name: "Treatment",
          is_control: false,
          traffic_allocation: 0,
          sort_order: 1
        })

      {:ok, _} =
        AssignmentPersistence.persist(%{
          tenant_id: tenant.id,
          experiment_id: experiment.id,
          variant_id: variant_1.id,
          user_id: "user-race"
        })

      # Second insert with different variant should not overwrite
      {:ok, _} =
        AssignmentPersistence.persist(%{
          tenant_id: tenant.id,
          experiment_id: experiment.id,
          variant_id: variant_2.id,
          user_id: "user-race"
        })

      # Original assignment should be preserved
      {:ok, assignment} =
        AssignmentPersistence.get_existing(tenant.id, experiment.id, "user-race")

      assert assignment.variant_id == variant_1.id
    end
  end
end
