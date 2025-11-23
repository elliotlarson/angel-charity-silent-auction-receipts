defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.AuctionItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config

  @shortdoc "Generate PDF receipts for all auction items"

  def run(_args) do
    ChromicPDFHelper.ensure_started()

    json_files = list_json_files()

    case json_files do
      [] ->
        Mix.shell().error("No JSON files found in #{Config.json_dir()}")

      files ->
        selected_file = prompt_file_selection(files)
        process_file(selected_file)
    end
  end

  defp list_json_files do
    json_dir = Config.json_dir()

    case File.ls(json_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp prompt_file_selection(files) do
    Mix.shell().info("Available JSON files:")

    files
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      Mix.shell().info("  #{index}. #{file}")
    end)

    input = Mix.shell().prompt("Select file number:") |> String.trim()

    case Integer.parse(input) do
      {selection, _} when selection > 0 and selection <= length(files) ->
        Enum.at(files, selection - 1)

      _ ->
        Mix.shell().error("Invalid selection. Please enter a number between 1 and #{length(files)}")
        prompt_file_selection(files)
    end
  end

  defp process_file(filename) do
    json_dir = Config.json_dir()
    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    Mix.shell().info("Generating receipts from #{filename}...")

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    items = load_auction_items(json_dir, filename)
    total = length(items)

    Mix.shell().info("Found #{total} auction items")

    results =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        generate_receipt(item, index, total, pdf_dir, html_dir)
      end)

    successful = Enum.count(results, fn result -> result == :ok end)
    failed = total - successful

    Mix.shell().info("\nGeneration complete!")
    Mix.shell().info("Successfully generated: #{successful} receipts")

    if failed > 0 do
      Mix.shell().error("Failed: #{failed} receipts")
    end
  end

  defp load_auction_items(json_dir, filename) do
    path = Path.join(json_dir, filename)
    {:ok, content} = File.read(path)
    {:ok, items_data} = Jason.decode(content)

    Enum.map(items_data, fn item_data ->
      AuctionItem.new(item_data)
    end)
  end

  defp generate_receipt(item, index, total, pdf_dir, html_dir) do
    snake_case_title = to_snake_case(item.short_title)
    base_filename = "receipt_#{item.item_id}_#{snake_case_title}"
    pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
    html_path = Path.join(html_dir, "#{base_filename}.html")

    Mix.shell().info("[#{index}/#{total}] Generating receipt for item ##{item.item_id}...")

    with :ok <- ReceiptGenerator.generate_pdf(item, pdf_path),
         :ok <- ReceiptGenerator.save_html(item, html_path) do
      :ok
    else
      {:error, reason} ->
        Mix.shell().error("Failed to generate receipt for item ##{item.item_id}: #{inspect(reason)}")
        :error
    end
  end

  defp to_snake_case(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
