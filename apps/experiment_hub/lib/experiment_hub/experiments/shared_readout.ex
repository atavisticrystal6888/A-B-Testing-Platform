defmodule ExperimentHub.Experiments.SharedReadout do
  @moduledoc """
  A stored, client-generated readout HTML snapshot exposed via a signed,
  unguessable Phoenix.Token capability link (Roadmap #7). See the moduledoc
  on migration 20260401000025 for why this table carries no tenant_isolation
  RLS policy.
  """

  use Ecto.Schema
  import Ecto.Changeset

  # Product call: reject stored readouts over 2MB — generous for a
  # self-contained HTML summary, cheap guard against abuse of an
  # unauthenticated-read table.
  @max_html_bytes 2_000_000

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shared_readouts" do
    field(:tenant_id, :binary_id)
    field(:html, :string)

    belongs_to(:experiment, ExperimentHub.Experiments.Experiment)

    timestamps(type: :utc_datetime)
  end

  def changeset(shared_readout, attrs) do
    shared_readout
    |> cast(attrs, [:tenant_id, :experiment_id, :html])
    |> validate_required([:tenant_id, :experiment_id, :html])
    |> validate_html_size()
  end

  defp validate_html_size(changeset) do
    validate_change(changeset, :html, fn :html, html ->
      if byte_size(html) > @max_html_bytes do
        [html: "must be at most #{@max_html_bytes} bytes"]
      else
        []
      end
    end)
  end
end
