defmodule Mix.Tasks.GenerateReceiptsTest do
  use Receipts.DataCase

  alias Mix.Tasks.GenerateReceipts

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(GenerateReceipts)
      assert function_exported?(GenerateReceipts, :run, 1)
    end
  end
end
