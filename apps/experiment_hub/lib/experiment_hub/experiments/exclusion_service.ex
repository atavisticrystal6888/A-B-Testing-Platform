defmodule ExperimentHub.Experiments.ExclusionService do
  @moduledoc """
  Service for managing mutual exclusion groups (FR-110).
  Ensures users assigned to one experiment in a group are excluded from others.
  """

  alias ExperimentHub.{Repo}
  alias ExperimentHub.Experiments.{ExclusionGroup, ExclusionGroupExperiment}
  import Ecto.Query

  @doc """
  Check if a user is already assigned to another experiment in the same exclusion group.
  Returns {:ok, :allowed} or {:ok, :excluded, experiment_id}.
  """
  def check_exclusion(experiment_id, user_id, tenant_id) do
    groups = get_groups_for_experiment(experiment_id)

    if groups == [] do
      {:ok, :allowed}
    else
      group_ids = Enum.map(groups, & &1.id)

      # Find other experiments in the same groups
      other_experiment_ids =
        from(ege in ExclusionGroupExperiment,
          where: ege.exclusion_group_id in ^group_ids,
          where: ege.experiment_id != ^experiment_id,
          select: ege.experiment_id
        )
        |> Repo.all()

      if other_experiment_ids == [] do
        {:ok, :allowed}
      else
        # Check if user has assignment in any of those experiments
        existing =
          from(a in ExperimentHub.Assignments.Assignment,
            where: a.tenant_id == ^tenant_id,
            where: a.experiment_id in ^other_experiment_ids,
            where: a.user_id == ^user_id,
            select: a.experiment_id,
            limit: 1
          )
          |> Repo.one()

        case existing do
          nil -> {:ok, :allowed}
          conflict_id -> {:ok, :excluded, conflict_id}
        end
      end
    end
  end

  defp get_groups_for_experiment(experiment_id) do
    from(eg in ExclusionGroup,
      join: ege in ExclusionGroupExperiment,
      on: ege.exclusion_group_id == eg.id,
      where: ege.experiment_id == ^experiment_id
    )
    |> Repo.all()
  end

  @doc """
  Create an exclusion group.
  """
  def create_group(attrs) do
    %ExclusionGroup{}
    |> ExclusionGroup.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Add an experiment to an exclusion group.
  """
  def add_experiment(group_id, experiment_id) do
    %ExclusionGroupExperiment{}
    |> ExclusionGroupExperiment.changeset(%{
      exclusion_group_id: group_id,
      experiment_id: experiment_id
    })
    |> Repo.insert()
  end

  @doc """
  Remove an experiment from an exclusion group.
  """
  def remove_experiment(group_id, experiment_id) do
    from(ege in ExclusionGroupExperiment,
      where: ege.exclusion_group_id == ^group_id,
      where: ege.experiment_id == ^experiment_id
    )
    |> Repo.delete_all()
  end

  @doc """
  List exclusion groups for a tenant.
  """
  def list_groups(tenant_id) do
    from(eg in ExclusionGroup,
      where: eg.tenant_id == ^tenant_id,
      preload: :experiments,
      order_by: [asc: eg.name]
    )
    |> Repo.all()
  end
end
