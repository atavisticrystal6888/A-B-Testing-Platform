defmodule ExperimentHub.Assignments.AssignmentPersistence do
  @moduledoc """
  Persists hash-based assignments to prevent flip-flopping when traffic
  allocation changes on a running experiment (FR-014).
  """

  import Ecto.Query
  alias ExperimentHub.Repo
  alias ExperimentHub.Assignments.Assignment

  @doc """
  Look up an existing assignment for a user in an experiment.
  Returns `{:ok, assignment}` or `{:error, :not_found}`.
  """
  def get_existing(tenant_id, experiment_id, user_id) do
    query =
      from(a in Assignment,
        where: a.tenant_id == ^tenant_id,
        where: a.experiment_id == ^experiment_id,
        where: a.user_id == ^user_id
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      assignment -> {:ok, assignment}
    end
  end

  @doc """
  Persist a new assignment. Uses ON CONFLICT DO NOTHING to handle races.
  Returns `{:ok, assignment}` or `{:error, changeset}`.
  """
  def persist(attrs) do
    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:tenant_id, :experiment_id, :user_id],
      returning: true
    )
  end
end
