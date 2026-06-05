defmodule ExperimentHubWeb.Plugs.RateLimiterTest do
  use ExperimentHubWeb.ConnCase, async: false

  alias ExperimentHubWeb.Plugs.RateLimiter

  defp redis_available? do
    case ExperimentHub.Redis.command(["PING"]) do
      {:ok, "PONG"} -> true
      _ -> false
    end
  end

  describe "call/2" do
    test "allows request when under rate limit", %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, %{id: "rate-test-#{System.unique_integer([:positive])}"})
        |> RateLimiter.call(RateLimiter.init(limit: 100, window: 60))

      refute conn.halted

      if redis_available?() do
        assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
        assert get_resp_header(conn, "x-ratelimit-remaining") != []
      end
    end

    @tag :redis
    test "blocks request when rate limit exceeded", %{conn: conn} do
      if not redis_available?() do
        IO.puts("Skipping: Redis not available")
      else
        key_id = "rate-exceeded-#{System.unique_integer([:positive])}"
        opts = RateLimiter.init(limit: 2, window: 60)

        # First two requests should pass
        _c1 =
          conn
          |> assign(:api_key, %{id: key_id})
          |> RateLimiter.call(opts)

        _c2 =
          Phoenix.ConnTest.build_conn()
          |> assign(:api_key, %{id: key_id})
          |> RateLimiter.call(opts)

        # Third request should be blocked
        blocked_conn =
          Phoenix.ConnTest.build_conn()
          |> put_req_header("accept", "application/json")
          |> assign(:api_key, %{id: key_id})
          |> RateLimiter.call(opts)

        assert blocked_conn.halted
        assert blocked_conn.status == 429
        assert get_resp_header(blocked_conn, "x-ratelimit-remaining") == ["0"]
        assert get_resp_header(blocked_conn, "retry-after") != []
      end
    end

    test "skips rate limiting when no identifiable key", %{conn: conn} do
      conn = RateLimiter.call(conn, RateLimiter.init(limit: 10, window: 60))

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") == []
    end

    test "sets standard rate limit headers when redis available", %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, %{id: "headers-test-#{System.unique_integer([:positive])}"})
        |> RateLimiter.call(RateLimiter.init(limit: 100, window: 60))

      if redis_available?() do
        assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
        assert get_resp_header(conn, "x-ratelimit-remaining") != []
        assert get_resp_header(conn, "x-ratelimit-reset") != []
      end
    end
  end
end
