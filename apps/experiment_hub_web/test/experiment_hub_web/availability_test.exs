defmodule ExperimentHubWeb.AvailabilityTest do
  use ExperimentHubWeb.ConnCase, async: true

  describe "health check" do
    test "GET /health returns 200", %{conn: conn} do
      conn = get(conn, "/health")
      assert json_response(conn, 200)
    end
  end
end
