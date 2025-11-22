defmodule Receipts.AuctionItemTest do
  use ExUnit.Case

  alias Receipts.AuctionItem

  describe "new/1" do
    test "creates struct with integer fields for item_id and fair_market_value" do
      attrs = %{
        item_id: "103",
        short_title: "Landscaping",
        title: "One Year Monthly Landscaping Services",
        description: "Enjoy a beautiful yard",
        fair_market_value: "1200",
        categories: "HOME"
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 103
      assert item.fair_market_value == 1200
      assert item.short_title == "Landscaping"
      assert item.title == "One Year Monthly Landscaping Services"
      assert item.description == "Enjoy a beautiful yard"
      assert item.categories == "HOME"
    end

    test "handles empty strings for numeric fields" do
      attrs = %{
        item_id: "",
        short_title: "Test",
        title: "Test Title",
        description: "Test Desc",
        fair_market_value: "",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 0
      assert item.fair_market_value == 0
    end

    test "handles nil values gracefully" do
      attrs = %{
        item_id: "103",
        short_title: nil,
        title: nil,
        description: nil,
        fair_market_value: "1200",
        categories: nil
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 103
      assert item.fair_market_value == 1200
      assert item.short_title == ""
      assert item.title == ""
      assert item.description == ""
      assert item.categories == ""
    end

    test "creates auction item with special_instructions and expiration_date" do
      attrs = %{
        item_id: "123",
        short_title: "Test",
        title: "Test Item",
        description: "Test description",
        fair_market_value: "100",
        categories: "TEST",
        special_instructions: "Contact us to book",
        expiration_date: "12/31/2026"
      }

      item = AuctionItem.new(attrs)

      assert item.special_instructions == "Contact us to book"
      assert item.expiration_date == "12/31/2026"
    end

    test "defaults special_instructions and expiration_date to empty strings" do
      attrs = %{
        item_id: "123",
        short_title: "Test",
        title: "Test Item",
        description: "Test description",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.special_instructions == ""
      assert item.expiration_date == ""
    end
  end
end
