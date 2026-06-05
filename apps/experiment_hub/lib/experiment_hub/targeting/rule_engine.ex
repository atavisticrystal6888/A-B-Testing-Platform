defmodule ExperimentHub.Targeting.RuleEngine do
  @moduledoc """
  Targeting rule evaluation engine (FR-090).
  Evaluates user attributes against experiment targeting rules with AND/OR logic.
  """

  alias ExperimentHub.{Repo}
  alias ExperimentHub.Targeting.TargetingRule
  import Ecto.Query

  @doc """
  Evaluate targeting rules for an experiment against user attributes.
  Returns true if user matches all rules.
  """
  def evaluate_experiment(experiment_id, user_attributes) do
    rules =
      from(r in TargetingRule,
        where: r.experiment_id == ^experiment_id,
        order_by: [asc: r.priority]
      )
      |> Repo.all()

    case rules do
      [] -> true
      rules -> ExperimentHub.Targeting.evaluate(format_rules(rules), user_attributes)
    end
  end

  @doc """
  Evaluate percentage-based targeting (FR-033).
  After rule evaluation, applies hash-based sampling.
  """
  def evaluate_percentage(_experiment_key, _user_id, percentage) when percentage >= 10000,
    do: true

  def evaluate_percentage(_experiment_key, _user_id, percentage) when percentage <= 0, do: false

  def evaluate_percentage(experiment_key, user_id, percentage) do
    hash_input = "#{experiment_key}:#{user_id}"
    bucket = :erlang.phash2(hash_input, 10000)
    bucket < percentage
  end

  defp format_rules(rules) do
    Enum.map(rules, fn rule ->
      %{
        "attribute" => rule.attribute,
        "operator" => rule.operator,
        "value" => rule.value
      }
    end)
  end
end
