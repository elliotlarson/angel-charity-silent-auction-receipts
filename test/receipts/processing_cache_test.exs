defmodule Receipts.ProcessingCacheTest do
  use ExUnit.Case

  alias Receipts.ProcessingCache

  @cache_dir "db/auction_items/cache"

  setup do
    File.rm_rf!(@cache_dir)
    on_exit(fn -> File.rm_rf!(@cache_dir) end)
    :ok
  end

  describe "get/1 and put/2" do
    test "returns nil when cache entry doesn't exist" do
      assert ProcessingCache.get("test description") == nil
    end

    test "stores and retrieves cached results" do
      description = "Test auction item description"

      result = %{
        "expiration_notice" => "12/31/2026",
        "notes" => "Call ahead",
        "description" => "Clean description"
      }

      ProcessingCache.put(description, result)
      cached = ProcessingCache.get(description)

      assert cached == {:ok, result}
    end

    test "different descriptions have different cache keys" do
      ProcessingCache.put("description 1", %{"value" => "1"})
      ProcessingCache.put("description 2", %{"value" => "2"})

      assert ProcessingCache.get("description 1") == {:ok, %{"value" => "1"}}
      assert ProcessingCache.get("description 2") == {:ok, %{"value" => "2"}}
    end
  end
end
