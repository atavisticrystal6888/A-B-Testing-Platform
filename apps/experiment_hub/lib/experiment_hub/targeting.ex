defmodule ExperimentHub.Targeting do
  @moduledoc """
  Targeting rules engine for experiments (FR-090).
  Evaluates user attributes against experiment targeting conditions.
  """

  @supported_operators ~w(eq neq gt gte lt lte in not_in contains not_contains matches)

  @doc """
  Evaluate targeting rules against user attributes.
  Returns true if user matches all rules (AND logic).
  """
  def evaluate(rules, user_attributes) when is_list(rules) do
    Enum.all?(rules, fn rule -> evaluate_rule(rule, user_attributes) end)
  end

  def evaluate(nil, _user_attributes), do: true
  def evaluate([], _user_attributes), do: true

  defp evaluate_rule(%{"attribute" => attr, "operator" => op, "value" => value}, user_attributes) do
    user_value = get_nested_attribute(user_attributes, attr)
    apply_operator(op, user_value, value)
  end

  defp evaluate_rule(%{"or" => conditions}, user_attributes) do
    Enum.any?(conditions, fn rule -> evaluate_rule(rule, user_attributes) end)
  end

  defp evaluate_rule(%{"and" => conditions}, user_attributes) do
    Enum.all?(conditions, fn rule -> evaluate_rule(rule, user_attributes) end)
  end

  defp evaluate_rule(%{"not" => condition}, user_attributes) do
    !evaluate_rule(condition, user_attributes)
  end

  defp get_nested_attribute(attrs, key) when is_map(attrs) do
    keys = String.split(key, ".")
    get_in_path(attrs, keys)
  end

  defp get_nested_attribute(_, _), do: nil

  defp get_in_path(value, []), do: value

  defp get_in_path(map, [key | rest]) when is_map(map) do
    get_in_path(Map.get(map, key) || Map.get(map, String.to_existing_atom(key)), rest)
  rescue
    ArgumentError -> nil
  end

  defp get_in_path(_, _), do: nil

  defp apply_operator("eq", user_val, target_val), do: user_val == target_val
  defp apply_operator("neq", user_val, target_val), do: user_val != target_val

  defp apply_operator("gt", user_val, target_val)
       when is_number(user_val) and is_number(target_val),
       do: user_val > target_val

  defp apply_operator("gte", user_val, target_val)
       when is_number(user_val) and is_number(target_val),
       do: user_val >= target_val

  defp apply_operator("lt", user_val, target_val)
       when is_number(user_val) and is_number(target_val),
       do: user_val < target_val

  defp apply_operator("lte", user_val, target_val)
       when is_number(user_val) and is_number(target_val),
       do: user_val <= target_val

  defp apply_operator("in", user_val, target_list) when is_list(target_list),
    do: user_val in target_list

  defp apply_operator("not_in", user_val, target_list) when is_list(target_list),
    do: user_val not in target_list

  defp apply_operator("contains", user_val, target_val) when is_binary(user_val),
    do: String.contains?(user_val, target_val)

  defp apply_operator("not_contains", user_val, target_val) when is_binary(user_val),
    do: !String.contains?(user_val, target_val)

  defp apply_operator("matches", user_val, pattern)
       when is_binary(user_val) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, user_val)
      {:error, _} -> false
    end
  end

  defp apply_operator(_, _, _), do: false

  @doc """
  Validate targeting rules structure.
  """
  def validate_rules(rules) when is_list(rules) do
    errors =
      rules
      |> Enum.with_index()
      |> Enum.flat_map(fn {rule, idx} -> validate_rule(rule, idx) end)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  def validate_rules(nil), do: :ok
  def validate_rules(_), do: {:error, ["targeting_rules must be a list"]}

  defp validate_rule(%{"attribute" => _, "operator" => op, "value" => _}, _idx) do
    if op in @supported_operators, do: [], else: ["unsupported operator: #{op}"]
  end

  defp validate_rule(%{"or" => conditions}, _idx) when is_list(conditions) do
    Enum.flat_map(conditions, fn rule -> validate_rule(rule, 0) end)
  end

  defp validate_rule(%{"and" => conditions}, _idx) when is_list(conditions) do
    Enum.flat_map(conditions, fn rule -> validate_rule(rule, 0) end)
  end

  defp validate_rule(%{"not" => condition}, idx), do: validate_rule(condition, idx)

  defp validate_rule(_, idx), do: ["invalid rule at index #{idx}"]
end
