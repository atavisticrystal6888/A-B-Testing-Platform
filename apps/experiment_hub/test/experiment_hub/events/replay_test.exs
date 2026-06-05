defmodule ExperimentHub.Events.ReplayTest do
  use ExperimentHub.DataCase, async: true

  describe "replay_events Mix task" do
    test "task module exists" do
      assert Code.ensure_loaded?(Mix.Tasks.ReplayEvents)
    end
  end
end
