defmodule Mix.Tasks.RegenerateReceipt do
  use Mix.Task

  @shortdoc "Regenerate a PDF receipt from an edited HTML file"

  @moduledoc """
  Regenerates a PDF receipt from a manually-edited HTML file.

  ## Usage

      mix regenerate_receipt <item_id>

  ## Example

      mix regenerate_receipt 120

  This will:
  1. Find the HTML file for item #120 in receipts/html/
  2. Read the HTML content
  3. Generate a new PDF from the HTML
  4. Save it to receipts/pdf/ (overwriting the existing PDF)

  This is useful when you need to manually edit an HTML file to make it fit
  better on one page, then regenerate just that PDF without affecting others.
  """

  def run([]) do
    Mix.shell().error("Error: Item ID required")
    Mix.shell().info("Usage: mix regenerate_receipt <item_id>")
    Mix.shell().info("Example: mix regenerate_receipt 120")
    exit({:shutdown, 1})
  end

  def run([item_id_str | _]) do
    ensure_chromic_pdf_started()

    case Integer.parse(item_id_str) do
      {item_id, _} ->
        regenerate_receipt(item_id)

      :error ->
        Mix.shell().error("Error: Invalid item ID '#{item_id_str}' - must be a number")
        exit({:shutdown, 1})
    end
  end

  defp regenerate_receipt(item_id) do
    html_dir = Application.get_env(:receipts, :html_dir, "receipts/html")
    pdf_dir = Application.get_env(:receipts, :pdf_dir, "receipts/pdf")

    # Find HTML file for this item_id
    html_files = Path.wildcard(Path.join(html_dir, "receipt_#{item_id}_*.html"))

    case html_files do
      [] ->
        Mix.shell().error("Error: No HTML file found for item ##{item_id}")
        Mix.shell().info("Looking in: #{html_dir}")
        exit({:shutdown, 1})

      [html_path] ->
        # Extract filename and create corresponding PDF path
        filename = Path.basename(html_path, ".html")
        pdf_path = Path.join(pdf_dir, "#{filename}.pdf")

        Mix.shell().info("Reading HTML from: #{Path.relative_to_cwd(html_path)}")
        Mix.shell().info("Generating PDF to: #{Path.relative_to_cwd(pdf_path)}")

        # Read HTML and generate PDF
        html_content = File.read!(html_path)

        case ChromicPDF.print_to_pdf({:html, html_content}, output: pdf_path) do
          :ok ->
            Mix.shell().info("✓ Successfully regenerated PDF for item ##{item_id}")

          {:error, reason} ->
            Mix.shell().error("Error generating PDF: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      multiple_files ->
        Mix.shell().error("Error: Multiple HTML files found for item ##{item_id}:")
        Enum.each(multiple_files, fn file ->
          Mix.shell().info("  - #{Path.relative_to_cwd(file)}")
        end)
        exit({:shutdown, 1})
    end
  end

  defp ensure_chromic_pdf_started do
    Application.ensure_all_started(:chromic_pdf)

    Process.flag(:trap_exit, true)

    case Supervisor.start_link([ChromicPDF], strategy: :one_for_one) do
      {:ok, _pid} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, {:shutdown, {:failed_to_start_child, ChromicPDF, {:already_started, _}}}} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, reason} ->
        Process.flag(:trap_exit, false)
        raise "Failed to start ChromicPDF: #{inspect(reason)}"
    end
  end
end
