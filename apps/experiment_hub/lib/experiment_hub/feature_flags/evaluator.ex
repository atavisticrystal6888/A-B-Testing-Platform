defmodule ExperimentHub.FeatureFlags.Evaluator do
  @moduledoc """
  Feature flag evaluation logic (FR-125), SDK-facing entry points.

  Delegates the actual decision to `ExperimentHub.FeatureFlags.FlagTargeting`
  so the SDK endpoint, the admin API, and bulk evaluation share one
  implementation (status + targeting rules + rollout bucketing).

  Unlike `FeatureFlags.evaluate/3`, unknown flags evaluate to `{:ok, false}`
  rather than an error — SDK clients treat missing flags as "off".
  """

  alias ExperimentHub.FeatureFlags
  alias ExperimentHub.FeatureFlags.FlagTargeting

  @doc """
  Evaluate a feature flag for a user.
  Returns {:ok, true/false}.
  """
  def evaluate(tenant_id, flag_key, user_id, user_attributes \\ %{}) do
    case FeatureFlags.get_flag_by_key(tenant_id, flag_key) do
      nil ->
        {:ok, false}

      flag ->
        {:ok, FlagTargeting.evaluate(flag, evaluation_context(user_id, user_attributes))}
    end
  end

  @doc """
  Evaluate multiple flags at once for a user.
  """
  def evaluate_all(tenant_id, user_id, user_attributes \\ %{}) do
    flags = FeatureFlags.list_flags(tenant_id)
    context = evaluation_context(user_id, user_attributes)

    results =
      Map.new(flags, fn flag ->
        {flag.key, FlagTargeting.evaluate(flag, context)}
      end)

    {:ok, results}
  end

  defp evaluation_context(user_id, user_attributes) do
    Map.put(user_attributes || %{}, "user_id", user_id)
  end
end
