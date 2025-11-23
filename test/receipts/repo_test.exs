defmodule Receipts.RepoTest do
  use Receipts.DataCase

  alias Receipts.Repo

  test "Repo is configured correctly" do
    config = Repo.config()
    assert config[:database] =~ "db/receipts_"
    assert config[:pool_size] == 5
  end

  test "Repo is running and can execute queries" do
    assert Process.whereis(Receipts.Repo) != nil
    assert {:ok, _result} = Repo.query("SELECT 1")
  end
end
