defmodule ExperimentHub.Assignments.AssignmentOverride do
  @moduledoc """
  QA force-assignment overrides (FR-015).
  Overrides take precedence over hash-based assignments.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assignment_overrides" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:variant_id, :binary_id)
    field(:user_id, :string)
    field(:reason, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(override, attrs) do
    override
    |> cast(attrs, [:tenant_id, :experiment_id, :variant_id, :user_id, :reason])
    |> validate_required([:tenant_id, :experiment_id, :variant_id, :user_id])
    |> validate_length(:user_id, max: 255)
    |> validate_length(:reason, max: 500)
    |> unique_constraint([:tenant_id, :experiment_id, :user_id])
  end
end
