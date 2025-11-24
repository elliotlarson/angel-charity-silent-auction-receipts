defmodule Mix.Tasks.GenerateReceipt do
  use Mix.Task
  alias Receipts.LineItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate HTML and PDF receipt for a single line item from database"

  @moduledoc """
  Generates both HTML and PDF receipts for a single line item from the database.

  ## Usage

      mix generate_receipt <line_item_id>

  ## Example

      mix generate_receipt 42

  This will:
  1. Look up line item #42 in the database
  2. Generate fresh HTML from the database data
  3. Generate PDF from the HTML
  4. Save both files to receipts/html/ and receipts/pdf/

  This is useful when you've updated a line item in the database and want to
  regenerate just that one receipt without regenerating all receipts.
  """

  def run([]) do
    Mix.shell().error("Error: Line item ID required")
    Mix.shell().info("Usage: mix generate_receipt <line_item_id>")
    Mix.shell().info("Example: mix generate_receipt 42")
    exit({:shutdown, 1})
  end

  def run([line_item_id_str | _]) do
    Application.ensure_all_started(:receipts)
    ChromicPDFHelper.ensure_started()

    case Integer.parse(line_item_id_str) do
      {line_item_id, _} ->
        generate_receipt(line_item_id)

      :error ->
        Mix.shell().error("Error: Invalid line item ID '#{line_item_id_str}' - must be a number")
        exit({:shutdown, 1})
    end
  end

  defp generate_receipt(line_item_id) do
    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    case Repo.get(LineItem, line_item_id) do
      nil ->
        Mix.shell().error("Error: Line item ##{line_item_id} not found in database")
        exit({:shutdown, 1})

      line_item ->
        snake_case_title = to_snake_case(line_item.short_title)
        base_filename = "receipt_#{line_item.item_identifier}_#{line_item.id}_#{snake_case_title}"
        pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
        html_path = Path.join(html_dir, "#{base_filename}.html")

        Mix.shell().info("Found line item ##{line_item_id}: #{line_item.title}")
        Mix.shell().info("Generating HTML to: #{Path.relative_to_cwd(html_path)}")
        Mix.shell().info("Generating PDF to: #{Path.relative_to_cwd(pdf_path)}")

        with :ok <- ReceiptGenerator.generate_pdf(line_item, pdf_path),
             :ok <- ReceiptGenerator.save_html(line_item, html_path) do
          Mix.shell().info("Successfully generated receipt for line item ##{line_item_id}")
        else
          {:error, reason} ->
            Mix.shell().error("Error generating receipt: #{inspect(reason)}")
            exit({:shutdown, 1})
        end
    end
  end

  defp to_snake_case(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
