defmodule AssignmentEngineTest do
  use ExUnit.Case
  doctest AssignmentEngine

  test "greets the world" do
    assert AssignmentEngine.hello() == :world
  end
end
