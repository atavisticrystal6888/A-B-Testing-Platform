defmodule ExperimentHubWeb.MetricsControllerTest do
  use ExperimentHubWeb.ConnCase, async: false

  describe "GET /metrics" do
    test "returns 200 with Prometheus text format", %{conn: conn} do
      # First request warms the aggregations (fires phoenix.endpoint events),
      # the second one is asserted on.
      get(conn, ~p"/metrics")
      conn = get(build_conn(), ~p"/metrics")

      assert conn.status == 200
      assert response_content_type(conn, :text) =~ "text/plain"

      # At least one known metric family must be present, with TYPE metadata.
      # Note: TelemetryMetricsPrometheus.Core converts the underlying value to
      # the declared unit but does not append a unit suffix to the family name
      # unless the metric's :name option explicitly includes one (it doesn't,
      # here) — so this stays unit-less rather than *_milliseconds.
      assert conn.resp_body =~ "# TYPE phoenix_endpoint_stop_duration histogram"
      assert conn.resp_body =~ "phoenix_endpoint_stop_duration"
    end

    test "requires no authentication and ignores Accept header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/plain")
        |> get(~p"/metrics")

      assert conn.status == 200
    end
  end
end
