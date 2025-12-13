defmodule Mix.Tasks.GenerateCombinedPdf do
  use Mix.Task
  import Ecto.Query
  alias Receipts.LineItem
  alias Receipts.Item
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate combined PDF for specified item identifiers"

  @moduledoc """
  Generate a combined PDF receipt file for specified item identifiers.

  ## Usage

      mix generate_combined_pdf 101,103,105

  This will create a combined PDF containing all line items for items 101, 103, and 105,
  sorted by item identifier and line item identifier.

  The output file will be named with the range of identifiers, e.g., combined_receipts_101_to_105.pdf.
  """

  def run(args) do
    Application.ensure_all_started(:receipts)

    item_identifiers = parse_item_identifiers(args)

    if Enum.empty?(item_identifiers) do
      Mix.shell().error("Error: No item identifiers provided")
      Mix.shell().info("Usage: mix generate_combined_pdf 101,103,105")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Generating combined PDF for items: #{Enum.join(item_identifiers, ", ")}")

    pdf_dir = Config.pdf_dir()

    line_items =
      from(li in LineItem,
        join: i in Item,
        on: li.item_id == i.id,
        where: i.item_identifier in ^item_identifiers,
        order_by: [asc: i.item_identifier, asc: li.identifier],
        preload: [item: i]
      )
      |> Repo.all()

    if Enum.empty?(line_items) do
      Mix.shell().error("Error: No line items found for the specified item identifiers")
      exit({:shutdown, 1})
    end

    found_identifiers = line_items |> Enum.map(& &1.item.item_identifier) |> Enum.uniq()
    missing_identifiers = item_identifiers -- found_identifiers

    if not Enum.empty?(missing_identifiers) do
      Mix.shell().info(
        "Warning: No data found for items: #{Enum.join(missing_identifiers, ", ")}"
      )
    end

    Mix.shell().info("Found #{length(line_items)} line items")

    pdf_paths =
      line_items
      |> Enum.map(fn line_item ->
        base_filename = LineItem.receipt_filename(line_item)
        Path.join(pdf_dir, "#{base_filename}.pdf")
      end)
      |> Enum.filter(fn path ->
        exists = File.exists?(path)

        if not exists do
          Mix.shell().info("Warning: PDF not found: #{Path.basename(path)}")
        end

        exists
      end)

    if Enum.empty?(pdf_paths) do
      Mix.shell().error("Error: No PDF files found for the specified items")
      Mix.shell().info("Hint: Run 'mix generate_receipts' first to create individual PDFs")
      exit({:shutdown, 1})
    end

    combine_pdfs(pdf_paths, pdf_dir, item_identifiers)
  end

  defp parse_item_identifiers(args) do
    args
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_integer/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {num, ""} when num > 0 ->
        num

      _ ->
        Mix.shell().info("Warning: Ignoring invalid item identifier: #{str}")
        nil
    end
  end

  defp combine_pdfs(pdf_paths, pdf_dir, item_identifiers) do
    min_id = Enum.min(item_identifiers)
    max_id = Enum.max(item_identifiers)
    filename = "combined_receipts_#{min_id}_to_#{max_id}.pdf"
    combined_path = Path.join(pdf_dir, filename)

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
        exit({:shutdown, 1})
    end
  end
end
