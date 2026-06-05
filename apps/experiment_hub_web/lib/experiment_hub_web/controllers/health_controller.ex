defmodule ExperimentHubWeb.HealthController do
  use ExperimentHubWeb, :controller

  def index(conn, _params) do
    checks = %{
      postgres: check_postgres(),
      redis: check_redis()
    }

    status = if Enum.all?(Map.values(checks), &(&1 == :ok)), do: :ok, else: :degraded
    http_status = if status == :ok, do: 200, else: 503

    conn
    |> put_status(http_status)
    |> json(%{
      status: status,
      version: Application.spec(:experiment_hub, :vsn) |> to_string(),
      checks: Map.new(checks, fn {k, v} -> {k, to_string(v)} end),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp check_postgres do
    case ExperimentHub.Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp check_redis do
    case ExperimentHub.Redis.command(["PING"]) do
      {:ok, "PONG"} -> :ok
      _ -> :error
    end
  end
end
