defmodule Mix.Tasks.GenerateReceiptTest do
  use Receipts.DataCase

  alias Mix.Tasks.GenerateReceipt

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(GenerateReceipt)
      assert function_exported?(GenerateReceipt, :run, 1)
    end
  end
end
