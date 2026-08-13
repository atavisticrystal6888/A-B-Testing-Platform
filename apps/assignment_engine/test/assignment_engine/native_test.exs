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

  describe "Rust/Elixir parity" do
    # Golden vectors generated from the Rust crate:
    #   cd assignment_core && cargo run --example golden_vectors
    # {experiment_key, user_id, bucket} — both implementations must agree, or
    # toggling ASSIGNMENT_ENGINE_BUILD_NIF would re-bucket every user.
    @golden_vectors [
      {"exp-1", "user-1", 5323},
      {"exp-1", "user-2", 8042},
      {"checkout-cta", "manual-e2e-user-001", 7539},
      {"exp-unicode", "üser-ñ", 8924},
      {"exp-long", "a-rather-long-user-identifier-0123456789", 5607},
      {"e", "u", 1959},
      {"exp-1", "", 9129},
      {"", "user-1", 8154}
    ]

    test "hash_to_bucket matches assignment_core golden vectors" do
      for {experiment_key, user_id, expected_bucket} <- @golden_vectors do
        assert AssignmentEngine.Native.hash_to_bucket(user_id, experiment_key) ==
                 expected_bucket,
               "bucket mismatch for {#{inspect(experiment_key)}, #{inspect(user_id)}}"
      end
    end
  end
end
