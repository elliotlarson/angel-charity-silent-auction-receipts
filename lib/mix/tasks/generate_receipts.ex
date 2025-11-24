defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.LineItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate PDF receipts for all line items"

  def run(_args) do
    Application.ensure_all_started(:receipts)
    ChromicPDFHelper.ensure_started()

    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    line_items = Repo.all(LineItem)
    total = length(line_items)

    Mix.shell().info("Generating receipts for #{total} line items...")

    results =
      line_items
      |> Enum.with_index(1)
      |> Enum.map(fn {line_item, index} ->
        generate_receipt(line_item, index, total, pdf_dir, html_dir)
      end)

    successful = Enum.count(results, fn result -> result == :ok end)
    failed = total - successful

    Mix.shell().info("\nGeneration complete!")
    Mix.shell().info("Successfully generated: #{successful} receipts")

    if failed > 0 do
      Mix.shell().error("Failed: #{failed} receipts")
    end
  end

  defp generate_receipt(line_item, index, total, pdf_dir, html_dir) do
    base_filename = LineItem.receipt_filename(line_item)
    pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
    html_path = Path.join(html_dir, "#{base_filename}.html")

    Mix.shell().info("[#{index}/#{total}] Generating receipt for item ##{line_item.item_identifier} (line item #{line_item.id})...")

    with :ok <- ReceiptGenerator.generate_pdf(line_item, pdf_path),
         :ok <- ReceiptGenerator.save_html(line_item, html_path) do
      :ok
    else
      {:error, reason} ->
        Mix.shell().error("Failed to generate receipt for line item ##{line_item.id}: #{inspect(reason)}")
        :error
    end
  end
end
