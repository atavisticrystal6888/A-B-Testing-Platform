defmodule ExperimentHub.Experiments.OverlapDetector do
  @moduledoc """
  Detects experiments that share the same feature_tag and are currently running.
  Returns warnings when creating/updating experiments that may overlap (FR-075).
  """

  import Ecto.Query
  alias ExperimentHub.Repo
  alias ExperimentHub.Experiments.Experiment

  @doc """
  Checks for running experiments with the same feature_tag.
  Returns a list of warning maps (empty if no overlaps or no feature_tag).
  """
  def check_overlaps(experiment_id, feature_tag, tenant_id) do
    if is_nil(feature_tag) or feature_tag == "" do
      []
    else
      overlapping =
        Experiment
        |> where([e], e.tenant_id == ^tenant_id)
        |> where([e], e.feature_tag == ^feature_tag)
        |> where([e], e.status == "running")
        |> where([e], e.id != ^experiment_id)
        |> select([e], %{id: e.id, key: e.key, name: e.name, status: e.status})
        |> Repo.all()

      case overlapping do
        [] ->
          []

        experiments ->
          [
            %{
              type: "experiment_overlap",
              message:
                "Running experiment(s) target the same feature tag '#{feature_tag}'. " <>
                  "Consider placing experiments in a mutual exclusion group.",
              overlapping_experiments: experiments
            }
          ]
      end
    end
  end
end
