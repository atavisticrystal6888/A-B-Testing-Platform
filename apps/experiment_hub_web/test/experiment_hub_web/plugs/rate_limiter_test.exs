defmodule ExperimentHubWeb.Plugs.RateLimiterTest do
  use ExperimentHubWeb.ConnCase, async: false

  alias ExperimentHubWeb.Plugs.RateLimiter

  # NOTE on Redis dependence: `RateLimiter.check_rate/3` fails *open* on any
  # Redis error (see the `{:error, _} -> {:allow, 0, reset_at}` clause), and
  # the allow-path headers below get set from that same fallback tuple, so
  # the assertions in "allows request when under rate limit" and "sets
  # standard rate limit headers" hold whether or not Redis is actually up —
  # they used to be wrapped in `if redis_available?() do`, but that guard
  # never hid a real gap for those two tests, it just added dead branching.
  # "blocks request when rate limit exceeded" is different: fail-open means
  # a request can never be denied without a live Redis actually incrementing
  # a counter, so that test is genuinely unprovable without Redis and is
  # tagged `:redis` — see test_helper.exs, which excludes that tag only when
  # Redis is verified unreachable, so a dead Redis shows up as "excluded" in
  # the ExUnit summary rather than a silent "passed".

  describe "call/2" do
    test "allows request when under rate limit", %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, %{id: "rate-test-#{System.unique_integer([:positive])}"})
        |> RateLimiter.call(RateLimiter.init(limit: 100, window: 60))

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
    end

    @tag :redis
    test "blocks request when rate limit exceeded", %{conn: conn} do
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

      assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end
  end
end
