defmodule ExperimentHub.Experiments.VariantValidator do
  @moduledoc """
  Validates variant configuration for an experiment:
  - At least 2 variants
  - Exactly one control variant
  - Traffic allocation must sum to 10,000 basis points
  """

  @doc """
  Validates a list of variant attrs maps.
  Returns `:ok` or `{:error, violations}` where violations is a list of strings.
  """
  def validate(variants) when is_list(variants) do
    violations =
      []
      |> check_minimum_count(variants)
      |> check_exactly_one_control(variants)
      |> check_traffic_sum(variants)

    case violations do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp check_minimum_count(violations, variants) do
    if length(variants) < 2 do
      ["at_least_two_variants_required" | violations]
    else
      violations
    end
  end

  defp check_exactly_one_control(violations, variants) do
    control_count =
      Enum.count(variants, fn v ->
        is_control = v["is_control"] || v[:is_control]
        is_control == true || is_control == "true"
      end)

    cond do
      control_count == 0 ->
        ["exactly_one_control_required" | violations]

      control_count > 1 ->
        ["only_one_control_allowed" | violations]

      true ->
        violations
    end
  end

  defp check_traffic_sum(violations, variants) do
    total =
      Enum.reduce(variants, 0, fn v, acc ->
        allocation = v["traffic_allocation"] || v[:traffic_allocation] || 0
        acc + to_integer(allocation)
      end)

    if total != 10_000 do
      ["traffic_allocation_must_sum_to_10000" | violations]
    else
      violations
    end
  end

  defp to_integer(v) when is_integer(v), do: v
  defp to_integer(v) when is_binary(v), do: String.to_integer(v)
  defp to_integer(_), do: 0
end
