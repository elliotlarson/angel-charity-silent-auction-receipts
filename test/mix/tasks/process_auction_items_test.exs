defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use ExUnit.Case

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(ProcessAuctionItems)
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end

  describe "is_placeholder_row?/1" do
    test "returns true when item_id is zero" do
      row_with_zero_id = ["", "0", "desc", "", "", "", "", "", "100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id) == true
    end

    test "returns true when fair_market_value is zero" do
      row_with_zero_fmv = ["", "103", "desc", "", "", "", "", "", "0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_fmv) == true
    end

    test "returns false for valid auction item row" do
      valid_row = ["", "103", "desc", "", "title", "", "description", "", "1200"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row) == false
    end
  end

  describe "build_item/3" do
    test "extracts all required fields from a row and converts numeric fields to integers" do
      headers = [
        "Apply Sales Tax? (Y/N)",
        "ITEM ID",
        "15 CHARACTER DESCRIPTION",
        "",
        "100 CHARACTER DESCRIPTION",
        "",
        "1500 CHARACTER DESCRIPTION (OPTIONAL)",
        "",
        "FAIR MARKET VALUE",
        "ITEM STARTING BID",
        "MINIMUM BID INCREMENT",
        "GROUP ID",
        "CATEGORIES (OPTIONAL)"
      ]

      row = [
        "",
        "103",
        "Landscaping",
        "11",
        "One Year Monthly Landscaping Services",
        "37",
        "Enjoy a beautiful yard",
        "570",
        "1200",
        "480",
        "100",
        " 1 ",
        "HOME"
      ]

      result = ProcessAuctionItems.build_item(row, headers, skip_ai_processing: true)

      assert result.item_id == 103
      assert result.categories == "HOME"
      assert result.short_title == "Landscaping"
      assert result.title == "One Year Monthly Landscaping Services"
      assert result.description == "<p>Enjoy a beautiful yard</p>"
      assert result.fair_market_value == 1200
    end

    test "returns AuctionItem struct with typed fields" do
      headers = [
        "ITEM ID",
        "15 CHARACTER DESCRIPTION",
        "100 CHARACTER DESCRIPTION",
        "1500 CHARACTER DESCRIPTION (OPTIONAL)",
        "FAIR MARKET VALUE",
        "CATEGORIES (OPTIONAL)"
      ]

      row = ["103", "Short", "Title", "Desc", "100", "CAT"]

      result = ProcessAuctionItems.build_item(row, headers, skip_ai_processing: true)

      assert is_struct(result, Receipts.AuctionItem)
      assert is_integer(result.item_id)
      assert is_integer(result.fair_market_value)
      assert is_binary(result.short_title)
      assert is_binary(result.title)
      assert is_binary(result.description)
      assert is_binary(result.categories)
    end

    test "trims whitespace from field values" do
      headers = ["ITEM ID", "CATEGORIES (OPTIONAL)"]
      row = ["  103  ", "  HOME  "]

      result = ProcessAuctionItems.build_item(row, headers, skip_ai_processing: true)

      assert result.item_id == 103
      assert result.categories == "HOME"
    end

    test "skips AI processing when flag is set" do
      row = ["Y", "103", "Short", "", "Title", "", "Description", "", "1200", "480", "100", "1", "HOME", "", "", "", ""]
      headers = ["Apply Sales Tax? (Y/N)", "ITEM ID", "15 CHARACTER DESCRIPTION", "", "100 CHARACTER DESCRIPTION", "", "1500 CHARACTER DESCRIPTION (OPTIONAL)", "", "FAIR MARKET VALUE", "ITEM STARTING BID", "MINIMUM BID INCREMENT", "GROUP ID", "CATEGORIES (OPTIONAL)", "", "BOA", "", ""]

      item = ProcessAuctionItems.build_item(row, headers, skip_ai_processing: true)

      assert item.item_id == 103
      assert item.short_title == "Short"
      assert item.title == "Title"
      assert item.description == "<p>Description</p>"
    end
  end

  describe "full processing pipeline" do
    @fixtures_dir "test/fixtures"
    @output_dir "test/tmp"

    setup do
      File.mkdir_p!(@output_dir)

      on_exit(fn ->
        File.rm_rf!(@output_dir)
      end)

      :ok
    end

    test "processes CSV and creates valid JSON output" do
      csv_path = Path.join(@fixtures_dir, "auction_items.csv")
      json_path = Path.join(@output_dir, "auction_items.json")

      items =
        csv_path
        |> ProcessAuctionItems.read_and_parse_csv()
        |> ProcessAuctionItems.clean_data(skip_ai_processing: true)

      json_content = Jason.encode!(items, pretty: true)
      File.write!(json_path, json_content)

      assert File.exists?(json_path)

      {:ok, json_data} = File.read(json_path)
      {:ok, decoded} = Jason.decode(json_data, keys: :atoms)

      assert length(decoded) == 3

      assert Enum.all?(decoded, fn item ->
               Map.has_key?(item, :item_id) and
                 Map.has_key?(item, :categories) and
                 Map.has_key?(item, :short_title) and
                 Map.has_key?(item, :title) and
                 Map.has_key?(item, :description) and
                 Map.has_key?(item, :fair_market_value)
             end)

      first_item = Enum.at(decoded, 0)
      assert first_item[:item_id] == 103
      assert first_item[:categories] == "HOME"
      assert first_item[:short_title] == "Landscaping"
      assert first_item[:fair_market_value] == 1200

      refute Enum.any?(decoded, fn item -> item[:item_id] == 110 end)
    end

    test "processes multi-line descriptions with HTML formatting" do
      csv_path = Path.join(@fixtures_dir, "auction_items.csv")

      items =
        csv_path
        |> ProcessAuctionItems.read_and_parse_csv()
        |> ProcessAuctionItems.clean_data(skip_ai_processing: true)

      item_125 = Enum.find(items, fn item -> item.item_id == 125 end)

      assert item_125 != nil
      assert item_125.short_title == "Wine Trip"
      assert item_125.title == "Portugal Wine Experience"

      expected_description = """
      <p>Win a trip to Portugal wine regions.</p>
      <h5>INCLUDES:</h5>
      <ul>
      <li>7 nights accommodation</li>
      <li>Wine tastings</li>
      <li>Cooking classes</li>
      </ul>
      <p>Travelers responsible for transportation.</p>
      <p>NOT INCLUDED: flights, meals</p>
      """
      |> String.trim()

      assert item_125.description == expected_description
    end
  end
end
