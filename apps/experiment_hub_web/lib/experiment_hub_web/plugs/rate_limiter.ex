defmodule ExperimentHubWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting Plug using Redis counters per API key per minute.
  Implements sliding window with standard rate limit response headers:
  - X-RateLimit-Limit
  - X-RateLimit-Remaining
  - X-RateLimit-Reset
  - Retry-After (on 429)
  """

  import Plug.Conn

  @default_limit 1000
  @window_seconds 60

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, @default_limit),
      window: Keyword.get(opts, :window, @window_seconds)
    }
  end

  def call(conn, %{limit: limit, window: window}) do
    key = rate_limit_key(conn)

    case key do
      nil ->
        # No identifiable key, skip rate limiting
        conn

      rate_key ->
        case check_rate(rate_key, limit, window) do
          {:allow, count, reset_at} ->
            remaining = max(limit - count, 0)

            conn
            |> put_resp_header("x-ratelimit-limit", to_string(limit))
            |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
            |> put_resp_header("x-ratelimit-reset", to_string(reset_at))

          {:deny, reset_at} ->
            retry_after = max(reset_at - System.system_time(:second), 1)

            conn
            |> put_resp_header("x-ratelimit-limit", to_string(limit))
            |> put_resp_header("x-ratelimit-remaining", "0")
            |> put_resp_header("x-ratelimit-reset", to_string(reset_at))
            |> put_resp_header("retry-after", to_string(retry_after))
            |> put_status(429)
            |> Phoenix.Controller.json(%{
              error: "rate_limited",
              message: "Rate limit exceeded. Try again in #{retry_after} seconds.",
              retry_after: retry_after
            })
            |> halt()
        end
    end
  end

  defp rate_limit_key(conn) do
    case conn.assigns do
      %{api_key: %{id: id}} -> "rate:apikey:#{id}"
      %{current_user_id: user_id} -> "rate:user:#{user_id}"
      _ -> nil
    end
  end

  defp check_rate(key, limit, window) do
    now = System.system_time(:second)
    reset_at = now + window
    window_key = "#{key}:#{div(now, window)}"

    case ExperimentHub.Redis.command(["INCR", window_key]) do
      {:ok, count} when count == 1 ->
        ExperimentHub.Redis.command(["EXPIRE", window_key, window])
        {:allow, count, reset_at}

      {:ok, count} when count <= limit ->
        {:allow, count, reset_at}

      {:ok, _count} ->
        {:deny, reset_at}

      {:error, _} ->
        # Redis unavailable — fail open
        {:allow, 0, reset_at}
    end
  end
end
