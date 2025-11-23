defmodule Mix.Tasks.GenerateReceiptsTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  alias Receipts.AuctionItem
  alias Receipts.Repo

  @test_pdf_dir "test/tmp/receipts/pdf"
  @test_html_dir "test/tmp/receipts/html"

  setup do
    File.mkdir_p!(@test_pdf_dir)
    File.mkdir_p!(@test_html_dir)

    # Insert test data into database
    Repo.insert!(%AuctionItem{
      item_id: 1,
      title: "Test Item 1",
      short_title: "Test One",
      description: "<p>Description 1</p>",
      fair_market_value: 100,
      categories: "",
      notes: "",
      expiration_notice: "",
      csv_row_hash: "hash1",
      csv_raw_line: "1,Test One,Test Item 1,..."
    })

    Repo.insert!(%AuctionItem{
      item_id: 2,
      title: "Test Item 2",
      short_title: "Test Two",
      description: "<p>Description 2</p>",
      fair_market_value: 200,
      categories: "",
      notes: "",
      expiration_notice: "",
      csv_row_hash: "hash2",
      csv_raw_line: "2,Test Two,Test Item 2,..."
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

  test "generates receipts for all auction items in database" do
    output =
      capture_io(fn ->
        Mix.Tasks.GenerateReceipts.run([])
      end)

    assert output =~ "Generating receipts for 2 auction items"
    assert output =~ "Successfully generated: 2 receipts"

    assert File.exists?(Path.join(@test_pdf_dir, "receipt_1_test_one.pdf"))
    assert File.exists?(Path.join(@test_pdf_dir, "receipt_2_test_two.pdf"))
    assert File.exists?(Path.join(@test_html_dir, "receipt_1_test_one.html"))
    assert File.exists?(Path.join(@test_html_dir, "receipt_2_test_two.html"))
  end
end
