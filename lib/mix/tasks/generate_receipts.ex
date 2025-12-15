defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  import Ecto.Query
  alias Receipts.LineItem
  alias Receipts.Item
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

    line_items =
      from(li in LineItem,
        join: i in Item,
        on: li.item_id == i.id,
        order_by: [asc: i.item_identifier, asc: li.identifier],
        preload: [item: i]
      )
      |> Repo.all()

    total = length(line_items)

    cleanup_orphan_files(line_items, pdf_dir, html_dir)

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

    # Generate combined PDF
    if successful > 0 do
      combine_pdfs(line_items, pdf_dir)
    end
  end

  defp generate_receipt(line_item, index, total, pdf_dir, html_dir) do
    base_filename = LineItem.receipt_filename(line_item)
    pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
    html_path = Path.join(html_dir, "#{base_filename}.html")

    Mix.shell().info(
      "[#{index}/#{total}] Generating receipt for item ##{line_item.item.item_identifier} (line item #{line_item.id})..."
    )

    with :ok <- ReceiptGenerator.generate_pdf(line_item, pdf_path),
         :ok <- ReceiptGenerator.save_html(line_item, html_path) do
      :ok
    else
      {:error, reason} ->
        Mix.shell().error(
          "Failed to generate receipt for line item ##{line_item.id}: #{inspect(reason)}"
        )

        :error
    end
  end

  defp cleanup_orphan_files(line_items, pdf_dir, html_dir) do
    expected_basenames =
      line_items
      |> Enum.map(&LineItem.receipt_filename/1)
      |> MapSet.new()

    cleanup_directory(pdf_dir, expected_basenames, ".pdf")
    cleanup_directory(html_dir, expected_basenames, ".html")
  end

  defp cleanup_directory(dir, expected_basenames, extension) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, extension))
        |> Enum.reject(fn file ->
          basename = String.replace_suffix(file, extension, "")
          MapSet.member?(expected_basenames, basename)
        end)
        |> Enum.each(fn file ->
          path = Path.join(dir, file)
          Mix.shell().info("Removing orphan file: #{file}")
          File.rm!(path)
        end)

      {:error, :enoent} ->
        :ok
    end
  end

  defp combine_pdfs(line_items, pdf_dir) do
    Mix.shell().info("\nCombining all PDFs into a single file...")

    # Get all PDF paths (line_items already sorted by item_identifier)
    pdf_paths =
      line_items
      |> Enum.map(fn line_item ->
        base_filename = LineItem.receipt_filename(line_item)
        Path.join(pdf_dir, "#{base_filename}.pdf")
      end)
      |> Enum.filter(&File.exists?/1)

    if Enum.empty?(pdf_paths) do
      Mix.shell().error("No PDFs found to combine")
      :error
    else
      combined_path = Path.join(pdf_dir, "combined_receipts.pdf")

      # Use ghostscript to combine PDFs
      args = [
        "-dBATCH",
        "-dNOPAUSE",
        "-q",
        "-sDEVICE=pdfwrite",
        "-sOutputFile=#{combined_path}"
        | pdf_paths
      ]

      case System.cmd("gs", args, stderr_to_stdout: true) do
        {_output, 0} ->
          Mix.shell().info("Combined PDF created: #{combined_path}")
          :ok

        {output, _code} ->
          Mix.shell().error("Failed to combine PDFs using ghostscript")
          Mix.shell().error(output)
          Mix.shell().info("Hint: Install ghostscript with 'brew install ghostscript' on macOS")

          :error
      end
    end
  end
end
