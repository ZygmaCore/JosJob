defmodule JosjobDocTest do
  use ExUnit.Case
  doctest JosjobDoc

  test "greets the world" do
    assert JosjobDoc.hello() == :world
  end
end
