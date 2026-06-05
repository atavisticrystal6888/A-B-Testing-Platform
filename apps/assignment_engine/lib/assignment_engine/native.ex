defmodule AssignmentEngine.Native do
  @moduledoc """
  Rustler NIF bindings for the assignment_core Rust library.
  Provides deterministic variant assignment using MurmurHash3.
  """

  # Only load Rustler NIF if cargo is available
  @cargo_available System.find_executable("cargo") != nil

  if @cargo_available do
    use Rustler,
      otp_app: :assignment_engine,
      crate: "assignment_core"
  end

  @doc """
  Hash user_id and experiment_key into a bucket in [0, 10000).
  """
  def hash_to_bucket(user_id, experiment_key)
      when is_binary(user_id) and is_binary(experiment_key) do
    hash_input = experiment_key <> ":" <> user_id

    <<bucket::unsigned-integer-size(32), _rest::binary>> = :crypto.hash(:sha256, hash_input)
    rem(bucket, 10_000)
  end

  @doc """
  Given a user_id, experiment_key, and list of traffic allocations (basis points),
  returns the index of the assigned variant.
  """
  def assign_variant(_user_id, _experiment_key, []), do: 0

  def assign_variant(user_id, experiment_key, allocations)
      when is_binary(user_id) and is_binary(experiment_key) and is_list(allocations) do
    bucket = hash_to_bucket(user_id, experiment_key)

    allocations
    |> Enum.reduce_while({0, 0}, fn allocation, {cumulative, index} ->
      next_cumulative = cumulative + allocation

      if bucket < next_cumulative do
        {:halt, index}
      else
        {:cont, {next_cumulative, index + 1}}
      end
    end)
    |> case do
      {_cumulative, index} -> min(index, length(allocations) - 1)
      index when is_integer(index) -> index
    end
  end
end
