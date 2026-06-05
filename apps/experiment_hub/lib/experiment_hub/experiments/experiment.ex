defmodule ExperimentHub.Experiments.Experiment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft running paused concluded)
  @conclusion_decisions ~w(ship_variant revert_to_control inconclusive)

  schema "experiments" do
    field(:tenant_id, :binary_id)
    field(:experiment_group_id, :binary_id)
    field(:key, :string)
    field(:name, :string)
    field(:hypothesis, :string)
    field(:description, :string)
    field(:feature_tag, :string)
    field(:status, :string, default: "draft")
    field(:conclusion_decision, :string)
    field(:conclusion_rationale, :string)
    field(:concluded_by, :binary_id)
    field(:scheduled_start_at, :utc_datetime)
    field(:scheduled_end_at, :utc_datetime)
    field(:started_at, :utc_datetime)
    field(:concluded_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    field(:winner_variant_id, :binary_id)
    field(:conclusion_reason, :string)
    field(:max_duration_days, :integer)
    field(:factors, {:array, :map})
    field(:targeting_rules, {:array, :map})
    field(:version, :integer, default: 1)
    field(:archived, :boolean, default: false)

    has_many(:variants, ExperimentHub.Experiments.Variant)
    has_many(:experiment_metrics, ExperimentHub.Metrics.ExperimentMetric)

    timestamps(type: :utc_datetime)
  end

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [
      :tenant_id,
      :key,
      :name,
      :hypothesis,
      :description,
      :feature_tag,
      :status,
      :experiment_group_id,
      :scheduled_start_at,
      :scheduled_end_at,
      :archived
    ])
    |> validate_required([:tenant_id, :key, :name])
    |> validate_length(:key, max: 100)
    |> validate_length(:name, max: 255)
    |> validate_length(:feature_tag, max: 100)
    |> validate_format(:key, ~r/^[a-z0-9][a-z0-9_-]*[a-z0-9]$/,
      message: "must be URL-safe lowercase with hyphens or underscores"
    )
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:tenant_id, :key])
  end

  def update_changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [
      :name,
      :hypothesis,
      :description,
      :feature_tag,
      :scheduled_start_at,
      :scheduled_end_at,
      :archived
    ])
    |> validate_length(:name, max: 255)
    |> validate_length(:feature_tag, max: 100)
    |> optimistic_lock(:version)
  end

  def conclude_changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [
      :conclusion_decision,
      :conclusion_rationale,
      :concluded_by,
      :concluded_at,
      :status,
      :ended_at,
      :winner_variant_id,
      :conclusion_reason
    ])
    |> validate_required([:conclusion_decision, :status])
    |> validate_inclusion(:conclusion_decision, @conclusion_decisions)
    |> optimistic_lock(:version)
  end

  def transition_changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [:status, :started_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
    |> optimistic_lock(:version)
  end

  def statuses, do: @statuses
  def conclusion_decisions, do: @conclusion_decisions
end
