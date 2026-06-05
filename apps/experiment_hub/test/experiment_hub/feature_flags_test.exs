defmodule ExperimentHub.FeatureFlagsTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.FeatureFlags

  @tenant_id Ecto.UUID.generate()

  def flag_fixture(attrs \\ %{}) do
    {:ok, flag} =
      attrs
      |> Enum.into(%{
        tenant_id: @tenant_id,
        key: "test-flag-#{System.unique_integer([:positive])}",
        name: "Test Flag",
        status: "enabled",
        rollout_percentage: 10_000
      })
      |> FeatureFlags.create_flag()

    flag
  end

  describe "create_flag/1" do
    test "creates a flag with valid attrs" do
      attrs = %{
        tenant_id: @tenant_id,
        key: "my-feature",
        name: "My Feature"
      }

      assert {:ok, flag} = FeatureFlags.create_flag(attrs)
      assert flag.key == "my-feature"
      assert flag.status == "disabled"
    end

    test "validates key format" do
      attrs = %{tenant_id: @tenant_id, key: "INVALID KEY!", name: "Test"}
      assert {:error, changeset} = FeatureFlags.create_flag(attrs)
      assert errors_on(changeset) |> Map.has_key?(:key)
    end
  end

  describe "evaluate/3" do
    test "returns true for enabled flag at 100%" do
      flag = flag_fixture(status: "enabled", rollout_percentage: 10_000)
      assert {:ok, true} = FeatureFlags.evaluate(@tenant_id, flag.key)
    end

    test "returns false for disabled flag" do
      flag = flag_fixture(status: "disabled")
      assert {:ok, false} = FeatureFlags.evaluate(@tenant_id, flag.key)
    end

    test "returns error for unknown flag" do
      assert {:error, :not_found} = FeatureFlags.evaluate(@tenant_id, "nonexistent")
    end

    test "deterministic rollout by user_id" do
      flag = flag_fixture(status: "enabled", rollout_percentage: 5000)

      results =
        for i <- 1..100 do
          {:ok, val} = FeatureFlags.evaluate(@tenant_id, flag.key, %{"user_id" => "user_#{i}"})
          val
        end

      # Should have some true and some false
      true_count = Enum.count(results, & &1)
      assert true_count > 10
      assert true_count < 90
    end
  end

  describe "evaluate_all/3" do
    test "evaluates multiple flags" do
      f1 = flag_fixture(status: "enabled", rollout_percentage: 10_000)
      f2 = flag_fixture(status: "disabled")

      results = FeatureFlags.evaluate_all(@tenant_id, [f1.key, f2.key])

      assert results[f1.key] == true
      assert results[f2.key] == false
    end
  end

  describe "list_flags/2" do
    test "lists flags for tenant" do
      flag_fixture()
      flag_fixture()

      flags = FeatureFlags.list_flags(@tenant_id)
      assert length(flags) >= 2
    end
  end
end
