defmodule ExperimentHubWeb.AvailabilityTest do
  use ExperimentHubWeb.ConnCase, async: true

  defp redis_available? do
    case ExperimentHub.Redis.command(["PING"]) do
      {:ok, "PONG"} -> true
      _ -> false
    end
  end

  describe "health check" do
    test "GET /health reflects dependency availability", %{conn: conn} do
      conn = get(conn, "/health")

      if redis_available?() do
        assert json_response(conn, 200)
      else
        # Without Redis the endpoint must degrade to 503, not report healthy.
        assert json_response(conn, 503)["checks"]["redis"] == "error"
      end
    end
  end
end
