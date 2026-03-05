defmodule HippoNativeTest do
  use ExUnit.Case
  doctest HippoNative

  test "greets the world" do
    assert HippoNative.hello() == :world
  end
end
