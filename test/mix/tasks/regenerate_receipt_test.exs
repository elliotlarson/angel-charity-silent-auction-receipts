defmodule Mix.Tasks.RegenerateReceiptTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @test_html_dir "test/tmp/receipts/html"
  @test_pdf_dir "test/tmp/receipts/pdf"

  setup do
    File.mkdir_p!(@test_html_dir)
    File.mkdir_p!(@test_pdf_dir)

    # Create a sample HTML file
    html_content = """
    <!DOCTYPE html>
    <html>
    <head><title>Test Receipt</title></head>
    <body><h1>Test Receipt for Item #999</h1></body>
    </html>
    """

    html_path = Path.join(@test_html_dir, "receipt_999_test_item.html")
    File.write!(html_path, html_content)

    original_html_dir = Application.get_env(:receipts, :html_dir)
    original_pdf_dir = Application.get_env(:receipts, :pdf_dir)

    Application.put_env(:receipts, :html_dir, @test_html_dir)
    Application.put_env(:receipts, :pdf_dir, @test_pdf_dir)

    on_exit(fn ->
      File.rm_rf!("test/tmp/receipts")

      if original_html_dir do
        Application.put_env(:receipts, :html_dir, original_html_dir)
      else
        Application.delete_env(:receipts, :html_dir)
      end

      if original_pdf_dir do
        Application.put_env(:receipts, :pdf_dir, original_pdf_dir)
      else
        Application.delete_env(:receipts, :pdf_dir)
      end
    end)

    :ok
  end

  test "regenerates PDF from HTML file" do
    output = capture_io(fn ->
      Mix.Tasks.RegenerateReceipt.run(["999"])
    end)

    assert output =~ "Reading HTML from:"
    assert output =~ "receipt_999_test_item.html"
    assert output =~ "Generating PDF to:"
    assert output =~ "receipt_999_test_item.pdf"
    assert output =~ "Successfully regenerated PDF for item #999"

    pdf_path = Path.join(@test_pdf_dir, "receipt_999_test_item.pdf")
    assert File.exists?(pdf_path)
    assert File.stat!(pdf_path).size > 0
  end

  test "errors when no HTML file found" do
    try do
      capture_io(fn ->
        Mix.Tasks.RegenerateReceipt.run(["888"])
      end)
    catch
      :exit, {:shutdown, 1} -> :ok
    end

    # Verify no PDF was created
    refute File.exists?(Path.join(@test_pdf_dir, "receipt_888_*.pdf"))
  end

  test "errors when no item ID provided" do
    try do
      capture_io(fn ->
        Mix.Tasks.RegenerateReceipt.run([])
      end)
    catch
      :exit, {:shutdown, 1} -> :ok
    end
  end
end
