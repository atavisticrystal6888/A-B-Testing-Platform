defmodule ExperimentHub.Targeting.TargetingRule do
  @moduledoc """
  Ecto schema for experiment targeting rules (FR-090).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "targeting_rules" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:attribute, :string)
    field(:operator, :string)
    field(:value, :map)
    field(:priority, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(tenant_id experiment_id attribute operator value)a
  @optional_fields ~w(priority)a

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(
      :operator,
      ~w(eq neq gt gte lt lte in not_in contains not_contains matches)
    )
  end
end
