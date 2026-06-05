defmodule ExperimentHub.Experiments.StateMachine do
  @moduledoc """
  Experiment state machine transitions.

  Valid transitions:
    draft    → running
    running  → paused
    running  → concluded
    paused   → running
    paused   → concluded
  """

  @valid_transitions %{
    "draft" => ["running"],
    "running" => ["paused", "concluded"],
    "paused" => ["running", "concluded"]
  }

  @doc """
  Returns whether a transition from `current_status` to `new_status` is valid.
  """
  def valid_transition?(current_status, new_status) do
    new_status in Map.get(@valid_transitions, current_status, [])
  end

  @doc """
  Validates a transition. Returns `:ok` or `{:error, reason}`.
  """
  def validate_transition(current_status, new_status) do
    if valid_transition?(current_status, new_status) do
      :ok
    else
      {:error,
       "Invalid transition from '#{current_status}' to '#{new_status}'. " <>
         "Valid transitions from '#{current_status}': #{inspect(valid_next_states(current_status))}"}
    end
  end

  @doc """
  Returns the list of valid next states for a given status.
  """
  def valid_next_states(status) do
    Map.get(@valid_transitions, status, [])
  end
end
