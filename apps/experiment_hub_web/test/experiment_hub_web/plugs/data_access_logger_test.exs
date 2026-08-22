defmodule ExperimentHubWeb.Plugs.DataAccessLoggerTest do
  # Logger.info is below config/test.exs's global :warning level, and
  # ExUnit.CaptureLog's own :level option only raises the *capture* floor,
  # not the global Logger.level/0 gate the message has to pass first — so
  # this raises the global level for the test and puts it back after.
  # Async: false because Logger.level/0 is process-global, not per-test.
  use ExperimentHubWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias ExperimentHubWeb.Plugs.DataAccessLogger

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)
    :ok
  end

  describe "call/2" do
    test "logs an API-key request with the key's id, not anonymous" do
      tenant = tenant_fixture()
      api_key = api_key_fixture(tenant: tenant)

      conn =
        build_conn(:get, "/api/v1/experiments")
        |> assign(:api_key, api_key)
        |> assign(:tenant_id, tenant.id)
        |> DataAccessLogger.call(DataAccessLogger.init([]))

      log = capture_log(fn -> Plug.Conn.send_resp(conn, 200, "ok") end)

      assert log =~ "DATA_ACCESS"
      assert log =~ "\"actor_id\":\"#{api_key.id}\""
    end

    test "falls back to anonymous when neither a user nor an api key is assigned" do
      conn =
        build_conn(:get, "/api/v1/experiments")
        |> DataAccessLogger.call(DataAccessLogger.init([]))

      log = capture_log(fn -> Plug.Conn.send_resp(conn, 200, "ok") end)

      assert log =~ "\"actor_id\":\"anonymous\""
    end

    test "does not register a logging hook for non-PII paths" do
      conn =
        build_conn(:get, "/health")
        |> DataAccessLogger.call(DataAccessLogger.init([]))

      log = capture_log(fn -> Plug.Conn.send_resp(conn, 200, "ok") end)

      refute log =~ "DATA_ACCESS"
    end
  end
end
