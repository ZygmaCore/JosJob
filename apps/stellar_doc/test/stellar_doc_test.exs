defmodule StellarDocTest do
  use ExUnit.Case
  doctest StellarDoc

  test "greets the world" do
    assert StellarDoc.hello() == :world
  end
end
