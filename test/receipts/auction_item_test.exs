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

  describe "normalize_text/1" do
    test "removes spaces before punctuation" do
      attrs = %{
        item_id: "1",
        short_title: "artist ,",
        title: "services .",
        description: "This is cubism . Very nice !",
        fair_market_value: "100",
        categories: "ART"
      }

      item = AuctionItem.new(attrs)

      assert item.short_title == "artist,"
      assert item.title == "services."
      assert item.description == "This is cubism. Very nice!"
    end

    test "adds spaces after sentence-ending punctuation" do
      attrs = %{
        item_id: "1",
        short_title: "Test",
        title: "Title",
        description: "sentence.Another sentence!Third sentence?Fourth",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.description == "sentence. Another sentence! Third sentence? Fourth"
    end

    test "collapses multiple spaces" do
      attrs = %{
        item_id: "1",
        short_title: "This  is",
        title: "a   test",
        description: "with    multiple     spaces",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.short_title == "This is"
      assert item.title == "a test"
      assert item.description == "with multiple spaces"
    end

    test "handles combined issues" do
      attrs = %{
        item_id: "1",
        short_title: "Test",
        title: "Test",
        description: "This is a  rare item.Good for  collectors ; you!Lounge here .",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.description == "This is a rare item. Good for collectors; you! Lounge here."
    end

    test "removes spaces before semicolons" do
      attrs = %{
        item_id: "1",
        short_title: "Test",
        title: "Test",
        description: "petting ; learning and grooming ; fun",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.description == "petting; learning and grooming; fun"
    end

    test "handles nil values" do
      attrs = %{
        item_id: "1",
        short_title: nil,
        title: nil,
        description: nil,
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.short_title == ""
      assert item.title == ""
      assert item.description == ""
    end

    test "handles already clean text" do
      attrs = %{
        item_id: "1",
        short_title: "Clean Title",
        title: "Another Clean Title",
        description: "This is already clean. No issues here!",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.short_title == "Clean Title"
      assert item.title == "Another Clean Title"
      assert item.description == "This is already clean. No issues here!"
    end
  end
end
