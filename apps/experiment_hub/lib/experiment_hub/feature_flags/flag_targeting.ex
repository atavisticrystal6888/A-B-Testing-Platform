defmodule ExperimentHub.FeatureFlags.FlagTargeting do
  @moduledoc """
  Targeting evaluation for feature flags (FR-135).
  Reuses the targeting engine from experiments.
  """

  alias ExperimentHub.Targeting

  @doc """
  Evaluate if a flag should be enabled based on targeting rules and context.
  Returns true if user matches targeting rules (or no rules exist) AND passes rollout check.
  """
  def evaluate(flag, context) do
    cond do
      flag.status == "disabled" ->
        false

      flag.targeting_rules == nil || flag.targeting_rules == [] ->
        evaluate_rollout(flag, context)

      Targeting.evaluate(flag.targeting_rules, context) ->
        evaluate_rollout(flag, context)

      true ->
        false
    end
  end

  defp evaluate_rollout(flag, context) do
    if flag.rollout_percentage >= 10_000 do
      true
    else
      user_id = Map.get(context, "user_id") || Map.get(context, :user_id, "")
      hash = :erlang.phash2({flag.key, user_id}, 10_000)
      hash < flag.rollout_percentage
    end
  end
end
