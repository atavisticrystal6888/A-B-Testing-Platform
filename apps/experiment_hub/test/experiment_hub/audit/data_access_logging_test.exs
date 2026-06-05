defmodule ExperimentHub.Audit.DataAccessLoggingTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHubWeb.Plugs.DataAccessLogger

  describe "DataAccessLogger plug" do
    test "plug module is loaded" do
      assert Code.ensure_loaded?(DataAccessLogger)
    end

    test "init/1 returns options" do
      assert DataAccessLogger.init([]) == []
    end
  end
end
