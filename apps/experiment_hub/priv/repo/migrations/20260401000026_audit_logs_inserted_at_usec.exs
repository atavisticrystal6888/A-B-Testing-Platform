defmodule ExperimentHub.Repo.Migrations.AuditLogsInsertedAtUsec do
  use Ecto.Migration

  @moduledoc """
  Widens `audit_logs.inserted_at` to microsecond precision.

  Lifecycle transitions (start/pause/resume/conclude) can be written by
  concurrent Oban workers and API requests within the same second, and the
  timeline view sorts strictly by `inserted_at` — second precision made
  same-second orderings ambiguous / arbitrary. RLS on the table is untouched.
  """

  def up do
    alter table(:audit_logs) do
      modify(:inserted_at, :utc_datetime_usec)
    end
  end

  def down do
    alter table(:audit_logs) do
      modify(:inserted_at, :utc_datetime)
    end
  end
end
