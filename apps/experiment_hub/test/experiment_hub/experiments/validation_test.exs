defmodule ExperimentHub.Experiments.ValidationTest do
  use ExUnit.Case, async: true

  alias ExperimentHub.Experiments.VariantValidator

  describe "VariantValidator.validate/1" do
    test "valid two-variant configuration" do
      variants = [
        %{"key" => "control", "is_control" => true, "traffic_allocation" => 5000},
        %{"key" => "treatment", "is_control" => false, "traffic_allocation" => 5000}
      ]

      assert :ok = VariantValidator.validate(variants)
    end

    test "valid three-variant configuration" do
      variants = [
        %{"key" => "control", "is_control" => true, "traffic_allocation" => 3334},
        %{"key" => "treatment-a", "is_control" => false, "traffic_allocation" => 3333},
        %{"key" => "treatment-b", "is_control" => false, "traffic_allocation" => 3333}
      ]

      assert :ok = VariantValidator.validate(variants)
    end

    test "rejects single variant" do
      variants = [
        %{"key" => "control", "is_control" => true, "traffic_allocation" => 10_000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "at_least_two_variants_required" in violations
    end

    test "rejects empty variants list" do
      assert {:error, violations} = VariantValidator.validate([])
      assert "at_least_two_variants_required" in violations
    end

    test "rejects variants with no control" do
      variants = [
        %{"key" => "a", "is_control" => false, "traffic_allocation" => 5000},
        %{"key" => "b", "is_control" => false, "traffic_allocation" => 5000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "exactly_one_control_required" in violations
    end

    test "rejects variants with multiple controls" do
      variants = [
        %{"key" => "a", "is_control" => true, "traffic_allocation" => 5000},
        %{"key" => "b", "is_control" => true, "traffic_allocation" => 5000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "only_one_control_allowed" in violations
    end

    test "rejects traffic allocation not summing to 10000" do
      variants = [
        %{"key" => "control", "is_control" => true, "traffic_allocation" => 6000},
        %{"key" => "treatment", "is_control" => false, "traffic_allocation" => 5000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "traffic_allocation_must_sum_to_10000" in violations
    end

    test "rejects traffic allocation summing to less than 10000" do
      variants = [
        %{"key" => "control", "is_control" => true, "traffic_allocation" => 3000},
        %{"key" => "treatment", "is_control" => false, "traffic_allocation" => 3000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "traffic_allocation_must_sum_to_10000" in violations
    end

    test "handles atom keys in variant maps" do
      variants = [
        %{key: "control", is_control: true, traffic_allocation: 5000},
        %{key: "treatment", is_control: false, traffic_allocation: 5000}
      ]

      assert :ok = VariantValidator.validate(variants)
    end

    test "can report multiple violations at once" do
      variants = [
        %{"key" => "a", "is_control" => false, "traffic_allocation" => 3000}
      ]

      assert {:error, violations} = VariantValidator.validate(variants)
      assert "at_least_two_variants_required" in violations
      assert "exactly_one_control_required" in violations
      assert "traffic_allocation_must_sum_to_10000" in violations
    end
  end
end
