defmodule ExperimentHub.Assignments.MutualExclusion do
  @moduledoc """
  Layer-based assignment for mutual exclusion groups (FR-110).
  Uses group-level hashing to deterministically assign users to experiment slots.
  """

  alias ExperimentHub.Experiments.ExclusionService

  @doc """
  Check mutual exclusion before assignment.
  Returns {:ok, :allowed} or {:ok, :excluded, conflicting_experiment_id}.
  """
  def check(experiment_id, user_id, tenant_id) do
    ExclusionService.check_exclusion(experiment_id, user_id, tenant_id)
  end

  @doc """
  Layer-based assignment: hash(layer_id + user_id) -> experiment slot -> variant.
  Within a mutual exclusion group, each user is deterministically assigned to one experiment.
  """
  def layer_assign(group_id, user_id, experiments) when is_list(experiments) do
    total_traffic = Enum.sum(Enum.map(experiments, fn e -> e.traffic_percentage || 10000 end))
    bucket = :erlang.phash2("#{group_id}:#{user_id}", total_traffic)

    find_experiment_slot(experiments, bucket, 0)
  end

  defp find_experiment_slot([], _bucket, _acc), do: nil

  defp find_experiment_slot([experiment | rest], bucket, acc) do
    traffic = experiment.traffic_percentage || 10000
    new_acc = acc + traffic

    if bucket < new_acc do
      experiment
    else
      find_experiment_slot(rest, bucket, new_acc)
    end
  end
end
