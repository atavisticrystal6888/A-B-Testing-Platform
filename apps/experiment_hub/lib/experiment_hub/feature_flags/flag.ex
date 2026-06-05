defmodule ExperimentHub.FeatureFlags.Flag do
  @moduledoc """
  Feature flag schema (FR-125).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(enabled disabled)

  schema "feature_flags" do
    field(:tenant_id, :binary_id)
    field(:key, :string)
    field(:name, :string)
    field(:description, :string)
    field(:status, :string, default: "disabled")
    field(:rollout_percentage, :integer, default: 10_000)
    field(:targeting_rules, {:array, :map}, default: [])
    field(:metadata, :map, default: %{})
    field(:stale_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(tenant_id key name)a
  @optional_fields ~w(description status rollout_percentage targeting_rules metadata stale_at)a

  def changeset(flag, attrs) do
    flag
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:rollout_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10_000
    )
    |> validate_format(:key, ~r/^[a-z][a-z0-9_.-]{0,254}$/)
    |> unique_constraint([:tenant_id, :key])
  end
end
