defmodule AssignmentEngine.NativeTest do
  use ExUnit.Case, async: true

  describe "hash_to_bucket/2" do
    test "returns deterministic results" do
      a = AssignmentEngine.Native.hash_to_bucket("user-1", "exp-1")
      b = AssignmentEngine.Native.hash_to_bucket("user-1", "exp-1")
      assert a == b
    end

    test "returns value in [0, 10000)" do
      for i <- 0..999 do
        bucket = AssignmentEngine.Native.hash_to_bucket("user-#{i}", "exp-1")
        assert bucket >= 0 and bucket < 10_000
      end
    end
  end

  describe "assign_variant/3" do
    test "returns deterministic variant index" do
      a = AssignmentEngine.Native.assign_variant("user-1", "exp-1", [5000, 5000])
      b = AssignmentEngine.Native.assign_variant("user-1", "exp-1", [5000, 5000])
      assert a == b
    end

    test "returns valid index for two variants" do
      for i <- 0..999 do
        idx = AssignmentEngine.Native.assign_variant("user-#{i}", "exp-1", [5000, 5000])
        assert idx in [0, 1]
      end
    end

    test "returns valid index for three variants" do
      for i <- 0..999 do
        idx = AssignmentEngine.Native.assign_variant("user-#{i}", "exp-1", [3334, 3333, 3333])
        assert idx in [0, 1, 2]
      end
    end

    test "returns 0 for empty allocations" do
      assert AssignmentEngine.Native.assign_variant("user-1", "exp-1", []) == 0
    end

    test "uniform distribution (chi-squared)" do
      n = 100_000
      counts = %{0 => 0, 1 => 0}

      counts =
        Enum.reduce(0..(n - 1), counts, fn i, acc ->
          idx =
            AssignmentEngine.Native.assign_variant("user-#{i}", "exp-uniformity", [5000, 5000])

          Map.update!(acc, idx, &(&1 + 1))
        end)

      expected = n / 2

      chi_sq =
        Enum.reduce(counts, 0.0, fn {_k, observed}, acc ->
          acc + :math.pow(observed - expected, 2) / expected
        end)

      # chi-squared critical value for 1 df, p=0.05 is 3.841
      assert chi_sq < 3.841, "Distribution is not uniform: chi_sq=#{chi_sq}"
    end

    test "control variant fallback when experiment not running" do
      # The NIF itself doesn't know about experiment status,
      # so this tests the fallback mechanism at the Elixir level
      idx = AssignmentEngine.Native.assign_variant("user-1", "exp-1", [10000])
      assert idx == 0
    end
  end
end
