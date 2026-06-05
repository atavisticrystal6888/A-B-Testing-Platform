defmodule ExperimentHub.Assignments.Assignment do
  @moduledoc """
  Ecto schema for variant assignments.
  Persists hash-based assignments for returning users to prevent flip-flopping (FR-014),
  and stores override assignments for QA/testing (FR-015).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assignments" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:variant_id, :binary_id)
    field(:user_id, :string)

    field(:assigned_at, :utc_datetime)
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:tenant_id, :experiment_id, :variant_id, :user_id, :assigned_at])
    |> validate_required([:tenant_id, :experiment_id, :variant_id, :user_id])
    |> put_assigned_at()
    |> validate_length(:user_id, max: 255)
    |> unique_constraint([:tenant_id, :experiment_id, :user_id])
  end

  defp put_assigned_at(changeset) do
    if get_field(changeset, :assigned_at) do
      changeset
    else
      put_change(changeset, :assigned_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
