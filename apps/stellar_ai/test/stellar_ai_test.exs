defmodule StellarAiTest do
  use ExUnit.Case
  doctest StellarAi

  test "greets the world" do
    assert StellarAi.hello() == :world
  end
end
