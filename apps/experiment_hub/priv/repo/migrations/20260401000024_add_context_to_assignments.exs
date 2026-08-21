defmodule ExperimentHub.Repo.Migrations.AddContextToAssignments do
  use Ecto.Migration

  @moduledoc """
  Stores the attributes map passed to /v1/assign on the assignment row, so
  results can be segmented by assignment-time context (country, device,
  ...). Rows created before this migration read as an empty map and fall
  into the "(unknown)" segment.
  """

  def change do
    alter table(:assignments) do
      add(:context, :map, default: %{}, null: false)
    end
  end
end
