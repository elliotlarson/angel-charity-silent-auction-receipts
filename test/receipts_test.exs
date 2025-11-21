defmodule ReceiptsTest do
  use ExUnit.Case
  doctest Receipts

  test "greets the world" do
    assert Receipts.hello() == :world
  end
end
