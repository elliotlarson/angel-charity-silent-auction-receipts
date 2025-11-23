defmodule Mix.Tasks.GenerateReceiptTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  alias Receipts.AuctionItem
  alias Receipts.Repo

  @test_pdf_dir "test/tmp/receipts/pdf"
  @test_html_dir "test/tmp/receipts/html"

  setup do
    File.mkdir_p!(@test_pdf_dir)
    File.mkdir_p!(@test_html_dir)

    # Insert test item into database
    Repo.insert!(%AuctionItem{
      item_id: 103,
      title: "Test Item",
      short_title: "Test",
      description: "<p>Test description</p>",
      fair_market_value: 500,
      categories: "TEST",
      notes: "Test notes",
      expiration_notice: "No expiration",
      csv_row_hash: "test_hash",
      csv_raw_line: "test,raw,line"
    })

    original_pdf_dir = Application.get_env(:receipts, :pdf_dir)
    original_html_dir = Application.get_env(:receipts, :html_dir)

    Application.put_env(:receipts, :pdf_dir, @test_pdf_dir)
    Application.put_env(:receipts, :html_dir, @test_html_dir)

    on_exit(fn ->
      File.rm_rf!("test/tmp")

      if original_pdf_dir do
        Application.put_env(:receipts, :pdf_dir, original_pdf_dir)
      else
        Application.delete_env(:receipts, :pdf_dir)
      end

      if original_html_dir do
        Application.put_env(:receipts, :html_dir, original_html_dir)
      else
        Application.delete_env(:receipts, :html_dir)
      end
    end)

    :ok
  end

  test "generates HTML and PDF for a single item from database" do
    output =
      capture_io(fn ->
        Mix.Tasks.GenerateReceipt.run(["103"])
      end)

    assert output =~ "Found item #103: Test Item"
    assert output =~ "Generating HTML to: test/tmp/receipts/html/receipt_103_test.html"
    assert output =~ "Generating PDF to: test/tmp/receipts/pdf/receipt_103_test.pdf"
    assert output =~ "Successfully generated receipt for item #103"

    assert File.exists?(Path.join(@test_pdf_dir, "receipt_103_test.pdf"))
    assert File.exists?(Path.join(@test_html_dir, "receipt_103_test.html"))

    # Verify HTML content
    html_content = File.read!(Path.join(@test_html_dir, "receipt_103_test.html"))
    assert html_content =~ "Test Item"
    assert html_content =~ "Test description"
  end

  test "reports error when item not found in database" do
    stderr =
      capture_io(:stderr, fn ->
        capture_io(fn ->
          try do
            Mix.Tasks.GenerateReceipt.run(["999"])
          catch
            :exit, _ -> :ok
          end
        end)
      end)

    assert stderr =~ "Error: Item #999 not found in database"
  end

  test "reports error when no item_id provided" do
    stderr =
      capture_io(:stderr, fn ->
        capture_io(fn ->
          try do
            Mix.Tasks.GenerateReceipt.run([])
          catch
            :exit, _ -> :ok
          end
        end)
      end)

    assert stderr =~ "Error: Item ID required"
  end

  test "reports error when item_id is not a number" do
    stderr =
      capture_io(:stderr, fn ->
        capture_io(fn ->
          try do
            Mix.Tasks.GenerateReceipt.run(["abc"])
          catch
            :exit, _ -> :ok
          end
        end)
      end)

    assert stderr =~ "Error: Invalid item ID 'abc' - must be a number"
  end
end
