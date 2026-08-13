defmodule ExperimentHub.Redis do
  @moduledoc """
  Redis connection via Redix. Used for caching and rate limiting.
  """

  @pool_size 5

  def child_spec(_opts) do
    children =
      for i <- 0..(@pool_size - 1) do
        Supervisor.child_spec(
          # Bounded by the fixed, compile-time @pool_size (5); this is the one
          # place these atoms are created, so downstream lookups can safely
          # use to_existing_atom instead of interpolating again per call.
          # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
          {Redix, {redis_url(), [name: :"redix_#{i}"]}},
          id: {Redix, i}
        )
      end

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one, name: __MODULE__]]}
    }
  end

  def command(command) do
    Redix.command(pool_name(random_index()), command)
  end

  def pipeline(commands) do
    Redix.pipeline(pool_name(random_index()), commands)
  end

  defp pool_name(index), do: String.to_existing_atom("redix_#{index}")

  defp random_index, do: Enum.random(0..(@pool_size - 1))

  defp redis_url do
    Application.get_env(:experiment_hub, :redis_url, "redis://localhost:6379")
  end
end
