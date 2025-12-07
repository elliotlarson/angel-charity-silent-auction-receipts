defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use Receipts.DataCase

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(ProcessAuctionItems)
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end

  describe "is_placeholder_row?/2" do
    test "returns true when qtego number is zero" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Detailed Item Description", "Value"]
      row_with_zero_id = ["6/5/2025", "0", "Some Item", "Description here", "$100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id, headers) == true
    end

    test "returns true when value is zero" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Detailed Item Description", "Value"]
      row_with_zero_value = ["6/5/2025", "103", "Some Item", "Description here", "$0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_value, headers) == true
    end

    test "returns true when title is empty" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Detailed Item Description", "Value"]
      row_with_empty_title = ["6/5/2025", "103", "", "Description here", "$100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_empty_title, headers) == true
    end

    test "returns true when description is empty" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Detailed Item Description", "Value"]
      row_with_empty_description = ["6/5/2025", "103", "Some Item", "", "$100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_empty_description, headers) == true
    end

    test "returns false for valid auction item row" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Detailed Item Description", "Value"]
      valid_row = ["6/5/2025", "103", "Landscaping Services", "Monthly service", "$1,200.00"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row, headers) == false
    end
  end

  describe "parse_value/1" do
    test "removes dollar signs and commas" do
      assert ProcessAuctionItems.parse_value("$1,200.00") == "1200"
      assert ProcessAuctionItems.parse_value("$2,400.00") == "2400"
      assert ProcessAuctionItems.parse_value("$500.00") == "500"
    end

    test "handles values without formatting" do
      assert ProcessAuctionItems.parse_value("1200") == "1200"
      assert ProcessAuctionItems.parse_value("500") == "500"
    end

    test "handles empty values" do
      assert ProcessAuctionItems.parse_value("") == ""
      assert ProcessAuctionItems.parse_value("$0") == "0"
    end
  end
end
