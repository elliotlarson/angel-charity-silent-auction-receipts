defmodule Receipts.ReceiptGeneratorTest do
  use ExUnit.Case
  alias Receipts.ReceiptGenerator
  alias Receipts.AuctionItem

  describe "render_html/1" do
    test "renders receipt template with auction item data" do
      item = AuctionItem.new(%{
        item_id: 103,
        title: "One Year Monthly Landscaping Services",
        description: "<p>Professional landscaping services.</p>",
        fair_market_value: 1200,
        notes: "Good for Tucson area.",
        expiration_notice: "No expiration date."
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "Item #103"
      assert html =~ "One Year Monthly Landscaping Services"
      assert html =~ "<p>Professional landscaping services.</p>"
      assert html =~ "$1,200.00"
      assert html =~ "Good for Tucson area."
      assert html =~ "No expiration date."
    end

    test "handles empty notes field" do
      item = AuctionItem.new(%{
        item_id: 104,
        title: "Test Item",
        description: "<p>Test description</p>",
        fair_market_value: 500,
        notes: "",
        expiration_notice: ""
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "Test Item"
      refute html =~ "Special Notes"
      refute html =~ "Expiration"
    end

    test "formats large currency values with commas" do
      item = AuctionItem.new(%{
        item_id: 999,
        title: "Expensive Item",
        description: "<p>Very valuable</p>",
        fair_market_value: 25000
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "$25,000.00"
    end
  end

  describe "generate_pdf/2" do
    setup do
      output_dir = "test/tmp"
      File.mkdir_p!(output_dir)
      on_exit(fn -> File.rm_rf!(output_dir) end)
      %{output_dir: output_dir}
    end

    test "generates PDF file", %{output_dir: output_dir} do
      item = AuctionItem.new(%{
        item_id: 103,
        title: "Test Item",
        description: "<p>Test description</p>",
        fair_market_value: 1200
      })

      output_path = Path.join(output_dir, "test_receipt.pdf")
      :ok = ReceiptGenerator.generate_pdf(item, output_path)

      assert File.exists?(output_path)
      assert File.stat!(output_path).size > 0
    end
  end
end
