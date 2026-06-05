defmodule ExperimentHub.Experiments.ExperimentGroup do
  @moduledoc """
  Experiment groups for mutual exclusion (FR-110).
  Alias for ExclusionGroup to match task naming convention.
  """

  # This module delegates to ExclusionGroup for backward compatibility
  defdelegate changeset(group, attrs), to: ExperimentHub.Experiments.ExclusionGroup
end
