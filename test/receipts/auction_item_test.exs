defmodule Receipts.AuctionItemTest do
  use ExUnit.Case
  import Ecto.Changeset, only: [get_change: 2]

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
      assert item.description == "<p>Enjoy a beautiful yard</p>"
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

    test "creates auction item with notes and expiration_notice" do
      attrs = %{
        item_id: "123",
        short_title: "Test",
        title: "Test Item",
        description: "Test description",
        fair_market_value: "100",
        categories: "TEST",
        notes: "Contact us to book",
        expiration_notice: "12/31/2026"
      }

      item = AuctionItem.new(attrs)

      assert item.notes == "Contact us to book"
      assert item.expiration_notice == "12/31/2026"
    end

    test "defaults notes and expiration_notice to empty strings" do
      attrs = %{
        item_id: "123",
        short_title: "Test",
        title: "Test Item",
        description: "Test description",
        fair_market_value: "100",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.notes == ""
      assert item.expiration_notice == ""
    end
  end

  describe "changeset/1" do
    test "casts string integers to integers" do
      attrs = %{
        item_id: "103",
        short_title: "Test",
        title: "Test Title",
        description: "Test description",
        fair_market_value: "1200",
        categories: "HOME"
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :item_id) == 103
      assert get_change(changeset, :fair_market_value) == 1200
    end

    test "applies defaults for nil values" do
      attrs = %{
        item_id: nil,
        short_title: nil,
        title: nil,
        description: nil,
        fair_market_value: nil,
        categories: nil
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :item_id) == 0
      assert get_change(changeset, :short_title) == ""
      assert get_change(changeset, :title) == ""
      assert get_change(changeset, :description) == ""
      assert get_change(changeset, :fair_market_value) == 0
      assert get_change(changeset, :categories) == ""
    end

    test "applies defaults for empty string numeric fields" do
      attrs = %{
        item_id: "",
        short_title: "Test",
        title: "Test",
        description: "Test",
        fair_market_value: "",
        categories: "TEST"
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :item_id) == 0
      assert get_change(changeset, :fair_market_value) == 0
    end

    test "normalizes text fields" do
      attrs = %{
        item_id: "1",
        short_title: "artist ,",
        title: "services .",
        description: "This is  a test.Good stuff !",
        fair_market_value: "100",
        categories: "ART"
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :short_title) == "artist,"
      assert get_change(changeset, :title) == "services."
      assert get_change(changeset, :description) == "<p>This is a test. Good stuff!</p>"
    end

    test "sets defaults for notes and expiration_notice" do
      attrs = %{
        item_id: "1",
        short_title: "Test",
        title: "Test",
        description: "Test",
        fair_market_value: "100",
        categories: "TEST"
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :notes) == ""
      assert get_change(changeset, :expiration_notice) == ""
    end

    test "preserves non-nil values" do
      attrs = %{
        item_id: "123",
        short_title: "Short",
        title: "Title",
        description: "Description",
        fair_market_value: "500",
        categories: "CATEGORY",
        notes: "Call ahead",
        expiration_notice: "12/31/2026"
      }

      changeset = AuctionItem.changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :notes) == "Call ahead"
      assert get_change(changeset, :expiration_notice) == "12/31/2026"
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
      assert item.description == "<p>This is cubism. Very nice!</p>"
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

      assert item.description == "<p>sentence. Another sentence! Third sentence? Fourth</p>"
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
      assert item.description == "<p>with multiple spaces</p>"
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

      assert item.description == "<p>This is a rare item. Good for collectors; you! Lounge here.</p>"
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

      assert item.description == "<p>petting; learning and grooming; fun</p>"
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
      assert item.description == "<p>This is already clean. No issues here!</p>"
    end
  end
end
