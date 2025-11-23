defmodule Mix.Tasks.GenerateReceiptsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @test_json_dir "test/tmp/json"
  @test_pdf_dir "test/tmp/receipts/pdf"
  @test_html_dir "test/tmp/receipts/html"

  setup do
    File.mkdir_p!(@test_json_dir)
    File.mkdir_p!(@test_pdf_dir)
    File.mkdir_p!(@test_html_dir)

    test_data = [
      %{
        item_id: 1,
        title: "Test Item 1",
        short_title: "Test One",
        description: "<p>Description 1</p>",
        fair_market_value: 100
      },
      %{
        item_id: 2,
        title: "Test Item 2",
        short_title: "Test Two",
        description: "<p>Description 2</p>",
        fair_market_value: 200
      }
    ]

    json_path = Path.join(@test_json_dir, "test_items.json")
    File.write!(json_path, Jason.encode!(test_data))

    original_json_dir = Application.get_env(:receipts, :json_dir)
    original_pdf_dir = Application.get_env(:receipts, :pdf_dir)
    original_html_dir = Application.get_env(:receipts, :html_dir)

    Application.put_env(:receipts, :json_dir, @test_json_dir)
    Application.put_env(:receipts, :pdf_dir, @test_pdf_dir)
    Application.put_env(:receipts, :html_dir, @test_html_dir)

    on_exit(fn ->
      File.rm_rf!("test/tmp")

      if original_json_dir do
        Application.put_env(:receipts, :json_dir, original_json_dir)
      else
        Application.delete_env(:receipts, :json_dir)
      end

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

  test "generates receipts for selected JSON file" do
    output =
      capture_io([input: "1\n"], fn ->
        Mix.Tasks.GenerateReceipts.run([])
      end)

    assert output =~ "Available JSON files:"
    assert output =~ "1. test_items.json"
    assert output =~ "Generating receipts from test_items.json"
    assert output =~ "Found 2 auction items"
    assert output =~ "Successfully generated: 2 receipts"

    assert File.exists?(Path.join(@test_pdf_dir, "receipt_1_test_one.pdf"))
    assert File.exists?(Path.join(@test_pdf_dir, "receipt_2_test_two.pdf"))
    assert File.exists?(Path.join(@test_html_dir, "receipt_1_test_one.html"))
    assert File.exists?(Path.join(@test_html_dir, "receipt_2_test_two.html"))
  end

  test "handles invalid file selection gracefully" do
    output =
      capture_io(:stderr, fn ->
        capture_io([input: "99\n1\n"], fn ->
          Mix.Tasks.GenerateReceipts.run([])
        end)
      end)

    assert output =~ "Invalid selection"
  end
end
