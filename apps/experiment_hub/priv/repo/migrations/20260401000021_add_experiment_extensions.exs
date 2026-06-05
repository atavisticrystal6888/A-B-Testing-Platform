defmodule ExperimentHub.Repo.Migrations.AddExperimentExtensions do
  use Ecto.Migration

  def change do
    alter table(:experiments) do
      add_if_not_exists :ended_at, :utc_datetime
      add_if_not_exists :winner_variant_id, :binary_id
      add_if_not_exists :conclusion_reason, :string
      add_if_not_exists :max_duration_days, :integer
      add_if_not_exists :factors, {:array, :map}, default: []
      add_if_not_exists :targeting_rules, {:array, :map}, default: []
    end
  end
end
