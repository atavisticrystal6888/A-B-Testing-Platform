defmodule ExperimentHub.Experiments.Variant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "variants" do
    field(:tenant_id, :binary_id)
    field(:key, :string)
    field(:name, :string)
    field(:description, :string)
    field(:is_control, :boolean, default: false)
    field(:traffic_allocation, :integer)
    field(:sort_order, :integer, default: 0)

    belongs_to(:experiment, ExperimentHub.Experiments.Experiment)

    timestamps(type: :utc_datetime)
  end

  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [
      :tenant_id,
      :experiment_id,
      :key,
      :name,
      :description,
      :is_control,
      :traffic_allocation,
      :sort_order
    ])
    |> validate_required([
      :tenant_id,
      :experiment_id,
      :key,
      :name,
      :is_control,
      :traffic_allocation
    ])
    |> validate_length(:key, max: 100)
    |> validate_length(:name, max: 255)
    |> validate_format(:key, ~r/^[a-z0-9][a-z0-9_-]*[a-z0-9]$|^[a-z0-9]$/,
      message: "must be URL-safe lowercase"
    )
    |> validate_number(:traffic_allocation,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10_000
    )
    |> unique_constraint([:tenant_id, :experiment_id, :key])
  end
end
