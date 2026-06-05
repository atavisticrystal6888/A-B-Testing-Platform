defmodule ExperimentHub.Targeting.Segment do
  @moduledoc """
  Reusable targeting segments that can be applied to experiments (FR-090).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "segments" do
    field(:tenant_id, :binary_id)
    field(:name, :string)
    field(:description, :string)
    field(:rules, :map)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(tenant_id name rules)a
  @optional_fields ~w(description)a

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:tenant_id, :name])
  end
end
