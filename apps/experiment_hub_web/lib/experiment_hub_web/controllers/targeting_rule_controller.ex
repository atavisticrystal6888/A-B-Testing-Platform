defmodule ExperimentHubWeb.TargetingRuleController do
  use ExperimentHubWeb, :controller
  action_fallback ExperimentHubWeb.FallbackController

  alias ExperimentHub.Repo
  alias ExperimentHub.Targeting.TargetingRule
  import Ecto.Query

  def index(conn, %{"experiment_id" => experiment_id}) do
    tenant_id = conn.assigns[:tenant_id]

    rules =
      from(r in TargetingRule,
        where: r.experiment_id == ^experiment_id and r.tenant_id == ^tenant_id,
        order_by: [asc: r.priority]
      )
      |> Repo.all()

    json(conn, %{data: Enum.map(rules, &format_rule/1)})
  end

  def create(conn, %{"experiment_id" => experiment_id} = params) do
    tenant_id = conn.assigns[:tenant_id]

    attrs =
      params
      |> Map.put("tenant_id", tenant_id)
      |> Map.put("experiment_id", experiment_id)

    changeset = TargetingRule.changeset(%TargetingRule{}, attrs)

    case Repo.insert(changeset) do
      {:ok, rule} ->
        conn
        |> put_status(:created)
        |> json(%{data: format_rule(rule)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns[:tenant_id]

    rule = Repo.get_by!(TargetingRule, id: id, tenant_id: tenant_id)
    Repo.delete!(rule)

    send_resp(conn, :no_content, "")
  end

  defp format_rule(rule) do
    %{
      id: rule.id,
      experiment_id: rule.experiment_id,
      attribute: rule.attribute,
      operator: rule.operator,
      value: rule.value,
      priority: rule.priority,
      inserted_at: rule.inserted_at
    }
  end
end
