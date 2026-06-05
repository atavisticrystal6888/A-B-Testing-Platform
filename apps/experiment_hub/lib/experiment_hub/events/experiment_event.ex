defmodule ExperimentHub.Events.ExperimentEvent do
  @moduledoc """
  Ecto schema for raw experiment events (partitioned table).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @event_types ~w(conversion metric revenue)

  schema "experiment_events_raw" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:variant_id, :binary_id)
    field(:user_id, :string)
    field(:event_type, :string)
    field(:event_name, :string)
    field(:value, :decimal)
    field(:properties, :map, default: %{})
    field(:idempotency_key, :string)
    field(:is_bot, :boolean, default: false)
    field(:is_post_conclusion, :boolean, default: false)
    field(:timestamp, :utc_datetime)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :tenant_id,
      :experiment_id,
      :variant_id,
      :user_id,
      :event_type,
      :event_name,
      :value,
      :properties,
      :idempotency_key,
      :is_bot,
      :is_post_conclusion,
      :timestamp
    ])
    |> validate_required([
      :tenant_id,
      :experiment_id,
      :user_id,
      :event_type,
      :event_name,
      :idempotency_key,
      :timestamp
    ])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_length(:user_id, max: 255)
    |> validate_length(:event_name, max: 100)
    |> validate_length(:idempotency_key, max: 255)
    |> validate_value_required()
    |> unique_constraint([:tenant_id, :idempotency_key])
  end

  defp validate_value_required(changeset) do
    event_type = get_field(changeset, :event_type)

    if event_type in ["metric", "revenue"] do
      validate_required(changeset, [:value])
    else
      changeset
    end
  end

  def event_types, do: @event_types
end
