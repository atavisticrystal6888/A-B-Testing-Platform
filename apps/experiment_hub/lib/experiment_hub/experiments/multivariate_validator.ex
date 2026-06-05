defmodule ExperimentHub.Experiments.MultivariateValidator do
  @moduledoc """
  Validates multivariate experiment configurations (FR-080).
  Ensures proper factor/level setup and traffic allocation.
  """

  @max_combinations 32

  @doc """
  Validate a multivariate experiment configuration.
  Returns :ok or {:error, reasons}.
  """
  def validate(experiment) do
    errors =
      []
      |> validate_factors(experiment)
      |> validate_combinations(experiment)
      |> validate_traffic(experiment)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_factors(errors, experiment) do
    factors = experiment.factors || []

    cond do
      length(factors) < 2 ->
        ["multivariate experiments require at least 2 factors" | errors]

      Enum.any?(factors, fn f -> length(f["levels"] || []) < 2 end) ->
        ["each factor must have at least 2 levels" | errors]

      true ->
        errors
    end
  end

  defp validate_combinations(errors, experiment) do
    factors = experiment.factors || []
    combinations = Enum.reduce(factors, 1, fn f, acc -> acc * length(f["levels"] || []) end)

    if combinations > @max_combinations do
      [
        "too many variant combinations (#{combinations}), maximum is #{@max_combinations}"
        | errors
      ]
    else
      errors
    end
  end

  defp validate_traffic(errors, experiment) do
    variants = experiment.variants || []
    total = Enum.reduce(variants, 0, fn v, acc -> acc + (v.traffic_allocation || 0) end)

    if total != 10_000 do
      ["traffic allocation must sum to 10000 (100%), got #{total}" | errors]
    else
      errors
    end
  end

  @doc """
  Generate full factorial variant combinations from factors.
  """
  def generate_combinations(factors) do
    factors
    |> Enum.map(fn %{"name" => name, "levels" => levels} ->
      Enum.map(levels, fn level -> {name, level} end)
    end)
    |> cartesian_product()
    |> Enum.with_index()
    |> Enum.map(fn {combo, idx} ->
      name = Enum.map(combo, fn {_factor, level} -> level end) |> Enum.join(" + ")
      key = Enum.map(combo, fn {factor, level} -> "#{factor}_#{level}" end) |> Enum.join("__")

      %{
        name: name,
        key: key,
        is_control: idx == 0,
        factor_levels: Map.new(combo),
        traffic_allocation: 0
      }
    end)
  end

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    rest = cartesian_product(tail)
    for x <- head, y <- rest, do: [x | y]
  end
end
