# The rate limiter's Redis-dependent path (`RateLimiterTest`'s "blocks
# request when rate limit exceeded") can only be proven with a live Redis:
# `ExperimentHubWeb.Plugs.RateLimiter` fails *open* when Redis is
# unreachable, so without Redis that path can never actually deny a
# request — an unconditional assertion would fail loudly (good), but a
# skip-when-down guard around the assertions used to make the run report a
# plain "passed" instead. Tests that genuinely require Redis are tagged
# `:redis`; that tag is excluded only when Redis is verified unreachable
# right here, so a dead Redis produces an "excluded" count in the ExUnit
# summary, never a silent "passed".
redis_reachable? =
  Enum.any?(1..5, fn attempt ->
    case ExperimentHub.Redis.command(["PING"]) do
      {:ok, "PONG"} ->
        true

      _ ->
        if attempt < 5, do: Process.sleep(100)
        false
    end
  end)

exclude_tags = if redis_reachable?, do: [], else: [:redis]

unless redis_reachable? do
  IO.puts(
    :stderr,
    "\n[test_helper] Redis unreachable at " <>
      "#{System.get_env("REDIS_URL", "redis://localhost:6380")} -- excluding " <>
      ":redis-tagged tests (they will show as \"excluded\", not \"passed\", below).\n"
  )
end

ExUnit.start(exclude: exclude_tags)

if Process.whereis(ExperimentHub.Repo) do
  Ecto.Adapters.SQL.Sandbox.mode(ExperimentHub.Repo, :manual)
end
