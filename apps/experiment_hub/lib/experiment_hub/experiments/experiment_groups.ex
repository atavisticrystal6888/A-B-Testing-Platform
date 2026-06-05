defmodule ExperimentHub.Experiments.ExperimentGroups do
  @moduledoc """
  Context for managing mutual exclusion experiment groups (FR-110).
  """

  alias ExperimentHub.Repo
  alias ExperimentHub.Experiments.{ExclusionGroup, ExclusionGroupExperiment}
  import Ecto.Query

  def list_groups(tenant_id) do
    from(g in ExclusionGroup,
      where: g.tenant_id == ^tenant_id,
      order_by: [asc: g.name],
      preload: [:experiments]
    )
    |> Repo.all()
  end

  def get_group!(id), do: Repo.get!(ExclusionGroup, id) |> Repo.preload(:experiments)

  def create_group(attrs) do
    %ExclusionGroup{}
    |> ExclusionGroup.changeset(attrs)
    |> Repo.insert()
  end

  def update_group(group, attrs) do
    group
    |> ExclusionGroup.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(group), do: Repo.delete(group)

  def add_experiment(group_id, experiment_id) do
    %ExclusionGroupExperiment{}
    |> ExclusionGroupExperiment.changeset(%{
      exclusion_group_id: group_id,
      experiment_id: experiment_id
    })
    |> Repo.insert()
  end

  def remove_experiment(group_id, experiment_id) do
    from(ege in ExclusionGroupExperiment,
      where: ege.exclusion_group_id == ^group_id and ege.experiment_id == ^experiment_id
    )
    |> Repo.delete_all()

    :ok
  end

  def release_traffic(group_id, experiment_id) do
    remove_experiment(group_id, experiment_id)
  end
end
