defmodule ExperimentHub.FeatureFlags.FeatureFlag do
  @moduledoc """
  Feature flag Ecto schema (FR-125).
  Alias module for the Flag schema to match task naming.
  """

  defdelegate changeset(flag, attrs), to: ExperimentHub.FeatureFlags.Flag
end
