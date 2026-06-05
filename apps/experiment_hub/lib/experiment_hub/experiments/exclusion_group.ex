defmodule ExperimentHub.Experiments.ExclusionGroup do
  @moduledoc """
  Mutual exclusion groups prevent users from being in multiple experiments (FR-110).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "exclusion_groups" do
    field(:tenant_id, :binary_id)
    field(:name, :string)
    field(:description, :string)

    many_to_many(:experiments, ExperimentHub.Experiments.Experiment,
      join_through: "exclusion_group_experiments"
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:tenant_id, :name, :description])
    |> validate_required([:tenant_id, :name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:tenant_id, :name])
  end
end
