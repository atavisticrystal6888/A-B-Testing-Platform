defmodule ExperimentHub.FeatureFlags.EvaluatorTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.FeatureFlags
  alias ExperimentHub.FeatureFlags.Evaluator

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

  describe "evaluate/4 (SDK path)" do
    # Regression: the evaluator used to gate on status == "active", a status
    # that no flag can have ("enabled"/"disabled" only), so every SDK
    # evaluation returned false.
    test "returns true for an enabled flag at full rollout" do
      flag = flag_fixture(status: "enabled", rollout_percentage: 10_000)
      assert {:ok, true} = Evaluator.evaluate(@tenant_id, flag.key, "user-1")
    end

    test "returns false for a disabled flag" do
      flag = flag_fixture(status: "disabled")
      assert {:ok, false} = Evaluator.evaluate(@tenant_id, flag.key, "user-1")
    end

    test "returns false (not an error) for an unknown flag" do
      assert {:ok, false} = Evaluator.evaluate(@tenant_id, "nonexistent", "user-1")
    end

    test "applies targeting rules from user attributes" do
      flag =
        flag_fixture(
          status: "enabled",
          rollout_percentage: 10_000,
          targeting_rules: [
            %{"attribute" => "country", "operator" => "eq", "value" => "US"}
          ]
        )

      assert {:ok, true} =
               Evaluator.evaluate(@tenant_id, flag.key, "user-1", %{"country" => "US"})

      assert {:ok, false} =
               Evaluator.evaluate(@tenant_id, flag.key, "user-1", %{"country" => "DE"})
    end

    test "rollout bucketing matches the admin API path" do
      flag = flag_fixture(status: "enabled", rollout_percentage: 5000)

      for user_id <- Enum.map(1..50, &"user-#{&1}") do
        {:ok, sdk_result} = Evaluator.evaluate(@tenant_id, flag.key, user_id)
        {:ok, admin_result} = FeatureFlags.evaluate(@tenant_id, flag.key, %{"user_id" => user_id})

        assert sdk_result == admin_result,
               "SDK and admin evaluation disagree for #{user_id}"
      end
    end
  end

  describe "evaluate_all/3" do
    test "evaluates every flag for the tenant" do
      enabled = flag_fixture(status: "enabled", rollout_percentage: 10_000)
      disabled = flag_fixture(status: "disabled")

      assert {:ok, results} = Evaluator.evaluate_all(@tenant_id, "user-1")
      assert results[enabled.key] == true
      assert results[disabled.key] == false
    end
  end
end
