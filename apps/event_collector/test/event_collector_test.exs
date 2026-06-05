defmodule EventCollectorTest do
  use ExUnit.Case
  doctest EventCollector

  test "greets the world" do
    assert EventCollector.hello() == :world
  end
end
