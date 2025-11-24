defmodule Mix.Tasks.MigrateJsonToDbTest do
  use Receipts.DataCase

  alias Mix.Tasks.MigrateJsonToDb

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(MigrateJsonToDb)
      assert function_exported?(MigrateJsonToDb, :run, 1)
    end
  end
end
