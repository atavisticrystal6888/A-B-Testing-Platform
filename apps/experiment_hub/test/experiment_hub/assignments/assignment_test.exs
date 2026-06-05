defmodule ExperimentHub.Assignments.AssignmentTest do
  use ExperimentHub.DataCase, async: false
  import ExperimentHub.TestFixtures

  alias ExperimentHub.Assignments

  setup do
    tenant = tenant_fixture()
    {:ok, tenant: tenant}
  end

  describe "assign/2" do
    test "returns fallback control when experiment not found", %{tenant: tenant} do
      result =
        Assignments.assign(tenant.id, %{
          "user_id" => "user-1",
          "experiment_key" => "nonexistent"
        })

      assert {:error, :experiment_not_found} = result
    end
  end

  describe "get_override/3" do
    test "returns error when no override exists", %{tenant: tenant} do
      assert {:error, :not_found} =
               Assignments.get_override(tenant.id, Ecto.UUID.generate(), "user-1")
    end
  end

  describe "create_override/1" do
    test "creates an override", %{tenant: tenant} do
      experiment = experiment_fixture(%{tenant: tenant})
      variant = variant_fixture(%{tenant: tenant, experiment: experiment})

      assert {:ok, override} =
               Assignments.create_override(%{
                 "tenant_id" => tenant.id,
                 "experiment_id" => experiment.id,
                 "variant_id" => variant.id,
                 "user_id" => "qa-user-1",
                 "reason" => "QA testing"
               })

      assert override.user_id == "qa-user-1"
      assert override.reason == "QA testing"
    end
  end
end
