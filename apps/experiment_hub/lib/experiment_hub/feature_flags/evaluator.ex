defmodule ExperimentHub.FeatureFlags.Evaluator do
  @moduledoc """
  Feature flag evaluation logic (FR-125).
  Evaluates flags based on enabled status, rollout percentage, and targeting rules.
  """

  alias ExperimentHub.FeatureFlags

  @doc """
  Evaluate a feature flag for a user.
  Returns {:ok, true/false} or {:error, reason}.
  """
  def evaluate(tenant_id, flag_key, user_id, user_attributes \\ %{}) do
    case FeatureFlags.get_flag_by_key(tenant_id, flag_key) do
      nil ->
        {:ok, false}

      flag ->
        result = evaluate_flag(flag, user_id, user_attributes)
        {:ok, result}
    end
  end

  @doc """
  Evaluate multiple flags at once for a user.
  """
  def evaluate_all(tenant_id, user_id, user_attributes \\ %{}) do
    flags = FeatureFlags.list_flags(tenant_id)

    results =
      Map.new(flags, fn flag ->
        {flag.key, evaluate_flag(flag, user_id, user_attributes)}
      end)

    {:ok, results}
  end

  defp evaluate_flag(flag, user_id, user_attributes) do
    cond do
      flag.status != "active" -> false
      not check_targeting(flag, user_attributes) -> false
      not check_rollout(flag, user_id) -> false
      true -> true
    end
  end

  defp check_targeting(flag, user_attributes) do
    case flag.targeting_rules do
      nil -> true
      [] -> true
      rules -> ExperimentHub.Targeting.evaluate(rules, user_attributes)
    end
  end

  defp check_rollout(flag, user_id) do
    case flag.rollout_percentage do
      nil ->
        true

      10000 ->
        true

      0 ->
        false

      pct ->
        bucket = :erlang.phash2("#{flag.key}:#{user_id}", 10000)
        bucket < pct
    end
  end
end
