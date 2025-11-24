defmodule Receipts.ReceiptGeneratorTest do
  use ExUnit.Case
  alias Receipts.ReceiptGenerator
  alias Receipts.LineItem

  defp test_line_item(overrides) do
    Map.merge(
      %LineItem{
        item_identifier: 1,
        identifier: 1,
        title: "Test",
        short_title: "Test",
        description: "<p>Test</p>",
        fair_market_value: 100,
        categories: "",
        notes: "",
        expiration_notice: "",
        csv_row_hash: "test_hash",
        csv_raw_line: "test,raw,line"
      },
      overrides
    )
  end

  describe "format_currency/1" do
    # Access private function for testing
    defp format_currency(value) do
      line_item = test_line_item(%{fair_market_value: value})
      html = ReceiptGenerator.render_html(line_item)
      [_before, currency, _after] = String.split(html, ~r/\$[\d,]+\.00/, include_captures: true)
      currency
    end

    test "formats single digit" do
      assert format_currency(5) == "$5.00"
    end

    test "formats hundreds" do
      assert format_currency(500) == "$500.00"
    end

    test "formats thousands with comma" do
      assert format_currency(1500) == "$1,500.00"
    end

    test "formats tens of thousands with comma" do
      assert format_currency(25000) == "$25,000.00"
    end

    test "formats millions with commas" do
      assert format_currency(1_250_000) == "$1,250,000.00"
    end

    test "formats zero" do
      assert format_currency(0) == "$0.00"
    end
  end

  describe "render_html/1" do
    test "renders receipt template with line item data" do
      line_item =
        test_line_item(%{
          item_identifier: 103,
          title: "One Year Monthly Landscaping Services",
          description: "<p>Professional landscaping services.</p>",
          fair_market_value: 1200,
          notes: "Good for Tucson area.",
          expiration_notice: "No expiration date."
        })

      html = ReceiptGenerator.render_html(line_item)

      assert html =~ "Item #103"
      assert html =~ "One Year Monthly Landscaping Services"
      assert html =~ "<p>Professional landscaping services.</p>"
      assert html =~ "$1,200.00"
      assert html =~ "Good for Tucson area."
      assert html =~ "No expiration date."
    end

    test "handles empty notes field" do
      line_item =
        test_line_item(%{
          item_identifier: 104,
          title: "Test Item",
          description: "<p>Test description</p>",
          fair_market_value: 500,
          notes: "",
          expiration_notice: ""
        })

      html = ReceiptGenerator.render_html(line_item)

      assert html =~ "Test Item"
      refute html =~ "Special Notes"
      refute html =~ "Expiration"
    end

    test "formats large currency values with commas" do
      line_item =
        test_line_item(%{
          item_identifier: 999,
          title: "Expensive Item",
          description: "<p>Very valuable</p>",
          fair_market_value: 25000
        })

      html = ReceiptGenerator.render_html(line_item)

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
      line_item =
        test_line_item(%{
          item_identifier: 103,
          title: "Test Item",
          description: "<p>Test description</p>",
          fair_market_value: 1200
        })

      output_path = Path.join(output_dir, "test_receipt.pdf")
      :ok = ReceiptGenerator.generate_pdf(line_item, output_path)

      assert File.exists?(output_path)
      assert File.stat!(output_path).size > 0
    end
  end
end
