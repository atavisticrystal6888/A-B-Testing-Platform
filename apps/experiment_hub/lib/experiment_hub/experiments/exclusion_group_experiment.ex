defmodule ExperimentHub.Experiments.ExclusionGroupExperiment do
  @moduledoc """
  Join table for exclusion group <-> experiment relationship.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "exclusion_group_experiments" do
    field(:exclusion_group_id, :binary_id)
    field(:experiment_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:exclusion_group_id, :experiment_id])
    |> validate_required([:exclusion_group_id, :experiment_id])
    |> unique_constraint([:exclusion_group_id, :experiment_id])
  end
end
