defmodule StellarJobTest do
  use ExUnit.Case
  doctest StellarJob

  test "greets the world" do
    assert StellarJob.hello() == :world
  end
end
