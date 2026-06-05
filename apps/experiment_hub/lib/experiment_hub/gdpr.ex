defmodule ExperimentHub.GDPR do
  @moduledoc """
  GDPR compliance - user data erasure and export (FR-300).
  """

  alias ExperimentHub.Repo
  alias ExperimentHub.Assignments.Assignment
  import Ecto.Query

  @doc """
  Erase all data for a specific user (Right to be forgotten).
  Anonymizes assignments and events.
  """
  def erase_user_data(tenant_id, user_id) do
    Repo.transaction(fn ->
      # Anonymize assignments
      anonymized_user_id = hash_user_id(user_id)

      from(a in Assignment,
        where: a.tenant_id == ^tenant_id and a.user_id == ^user_id
      )
      |> Repo.update_all(set: [user_id: anonymized_user_id])

      # Anonymize raw events
      Repo.query!(
        "UPDATE experiment_events_raw SET user_id = $1, properties = '{}'::jsonb WHERE tenant_id = $2 AND user_id = $3",
        [anonymized_user_id, tenant_id, user_id]
      )

      # Anonymize assignment overrides
      from(ao in ExperimentHub.Assignments.AssignmentOverride,
        where: ao.tenant_id == ^tenant_id and ao.user_id == ^user_id
      )
      |> Repo.delete_all()

      %{
        user_id: user_id,
        anonymized_to: anonymized_user_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
  end

  @doc """
  Export all data for a specific user (Right to data portability).
  """
  def export_user_data(tenant_id, user_id) do
    assignments =
      from(a in Assignment,
        where: a.tenant_id == ^tenant_id and a.user_id == ^user_id
      )
      |> Repo.all()
      |> Enum.map(fn a ->
        %{
          experiment_id: a.experiment_id,
          variant_id: a.variant_id,
          assigned_at: a.assigned_at
        }
      end)

    %{
      user_id: user_id,
      tenant_id: tenant_id,
      assignments: assignments,
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp hash_user_id(user_id) do
    :crypto.hash(:sha256, user_id)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 36)
  end
end
