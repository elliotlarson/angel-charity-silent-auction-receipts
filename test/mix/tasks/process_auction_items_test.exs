defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use Receipts.DataCase

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(ProcessAuctionItems)
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end

  describe "detect_format/1" do
    test "detects old format with ITEM ID header" do
      headers = ["", "ITEM ID", "15 CHARACTER DESCRIPTION", "FAIR MARKET VALUE"]
      assert ProcessAuctionItems.detect_format(headers) == :old_format
    end

    test "detects new format with TAG # header" do
      headers = ["Date", "Tag #", "Item Donated Title", "Value"]
      assert ProcessAuctionItems.detect_format(headers) == :new_format
    end

    test "returns unknown for unrecognized format" do
      headers = ["some", "random", "headers"]
      assert ProcessAuctionItems.detect_format(headers) == :unknown
    end

    test "handles case-insensitive header matching" do
      headers = ["", "item id", "description"]
      assert ProcessAuctionItems.detect_format(headers) == :old_format
    end
  end

  describe "field_mappings/1" do
    test "returns correct mappings for old format" do
      mappings = ProcessAuctionItems.field_mappings(:old_format)
      assert mappings["ITEM ID"] == :item_identifier
      assert mappings["15 CHARACTER DESCRIPTION"] == :short_title
      assert mappings["100 CHARACTER DESCRIPTION"] == :title
      assert mappings["1500 CHARACTER DESCRIPTION (OPTIONAL)"] == :description
      assert mappings["FAIR MARKET VALUE"] == :fair_market_value
      assert mappings["CATEGORIES (OPTIONAL)"] == :categories
    end

    test "returns correct mappings for new format" do
      mappings = ProcessAuctionItems.field_mappings(:new_format)
      assert mappings["TAG #"] == :item_identifier
      assert mappings["CATEGORY"] == :categories
      assert mappings["ITEM DONATED TITLE"] == :title
      assert mappings["DETAILED ITEM DESCRIPTION"] == :description
      assert mappings["VALUE"] == :fair_market_value
      assert Map.has_key?(mappings, "15 CHARACTER DESCRIPTION") == false
    end
  end

  describe "extract_numeric_identifier/1" do
    test "extracts number from SA-prefixed tags" do
      assert ProcessAuctionItems.extract_numeric_identifier("SA003") == "3"
      assert ProcessAuctionItems.extract_numeric_identifier("SA123") == "123"
      assert ProcessAuctionItems.extract_numeric_identifier("SA001") == "1"
    end

    test "handles already numeric values" do
      assert ProcessAuctionItems.extract_numeric_identifier("103") == "103"
    end

    test "handles empty or zero values" do
      assert ProcessAuctionItems.extract_numeric_identifier("SA000") == "0"
      assert ProcessAuctionItems.extract_numeric_identifier("") == "0"
    end
  end

  describe "is_placeholder_row?/3" do
    test "returns true when item_id is zero - old format" do
      headers = [
        "",
        "ITEM ID",
        "15 CHARACTER DESCRIPTION",
        "",
        "",
        "",
        "",
        "",
        "FAIR MARKET VALUE"
      ]

      row_with_zero_id = ["", "0", "desc", "", "", "", "", "", "100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id, headers, :old_format) ==
               true
    end

    test "returns true when fair_market_value is zero - old format" do
      headers = [
        "",
        "ITEM ID",
        "15 CHARACTER DESCRIPTION",
        "",
        "",
        "",
        "",
        "",
        "FAIR MARKET VALUE"
      ]

      row_with_zero_fmv = ["", "103", "desc", "", "", "", "", "", "0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_fmv, headers, :old_format) ==
               true
    end

    test "returns false for valid auction item row - old format" do
      headers = [
        "",
        "ITEM ID",
        "15 CHARACTER DESCRIPTION",
        "",
        "",
        "",
        "",
        "",
        "FAIR MARKET VALUE"
      ]

      valid_row = ["", "103", "desc", "", "title", "", "description", "", "1200"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row, headers, :old_format) == false
    end

    test "returns true when tag is zero - new format" do
      headers = ["Date", "Tag #", "Item Donated Title", "Value"]
      row_with_zero_id = ["6/5/2025", "0", "Some Item", "$100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id, headers, :new_format) ==
               true
    end

    test "returns true when value is zero - new format" do
      headers = ["Date", "Tag #", "Item Donated Title", "Value"]
      row_with_zero_value = ["6/5/2025", "SA003", "Some Item", "$0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_value, headers, :new_format) ==
               true
    end

    test "returns false for valid auction item row - new format" do
      headers = ["Date", "Tag #", "Item Donated Title", "Value"]
      valid_row = ["6/5/2025", "SA003", "Landscaping Services", "$1,200.00"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row, headers, :new_format) == false
    end
  end
end
