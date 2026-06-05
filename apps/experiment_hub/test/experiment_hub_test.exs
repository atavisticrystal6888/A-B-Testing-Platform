defmodule ExperimentHubTest do
  use ExUnit.Case
  doctest ExperimentHub

  test "greets the world" do
    assert ExperimentHub.hello() == :world
  end
end
