defmodule ExperimentHub.GDPR.AnonymizationRequest do
  @moduledoc """
  Tracks GDPR anonymization request progress (FR-300).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "anonymization_requests" do
    field(:tenant_id, :binary_id)
    field(:user_id, :string)
    field(:status, :string, default: "pending")
    field(:records_processed, :integer, default: 0)
    field(:total_records, :integer)
    field(:completed_at, :utc_datetime)
    field(:error_message, :string)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(tenant_id user_id)a
  @optional_fields ~w(status records_processed total_records completed_at error_message)a

  def changeset(request, attrs) do
    request
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ~w(pending processing completed failed))
  end
end
