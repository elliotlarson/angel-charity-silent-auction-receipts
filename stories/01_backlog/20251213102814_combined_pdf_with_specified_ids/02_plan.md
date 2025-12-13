# Implementation Plan: Combined PDF With Specified IDs

## Progress Checklist

- [x] Step 1: Add mix task for generating combined PDF with specified item IDs
- [ ] Step 2: Update CLAUDE.md documentation with new mix task

## Overview

Currently, `mix generate_receipts` creates individual PDF receipts for all line items and combines them all into a single `combined_receipts.pdf` file. This plan adds a new mix task that allows generating a combined PDF with only specified item identifiers, useful for creating custom receipt packages.

## Key Design Decisions

- **New Mix Task**: Create `mix generate_combined_pdf` as a separate task rather than modifying `generate_receipts`
  - Keeps the existing workflow unchanged
  - Provides a focused, single-purpose command
  - Allows for different argument handling

- **Argument Format**: Accept comma-delimited item identifiers as command-line arguments
  - Example: `mix generate_combined_pdf 101,103,105`
  - Simple and intuitive for users

- **Output File**: Generate to `combined_receipts_{min}_to_{max}.pdf` where min and max are the lowest and highest item identifiers
  - Example: `combined_receipts_103_to_132.pdf`
  - Avoids overwriting the full combined PDF created by `generate_receipts`
  - Filename clearly indicates which items are included

- **Sorting**: Maintain the same sorting order (by item identifier, then line item identifier) as the main combined PDF for consistency

- **Error Handling**: Skip missing item identifiers with warnings rather than failing entirely

## Implementation Steps

### Step 1: Add mix task for generating combined PDF with specified item IDs

**Files to modify:**

- `lib/mix/tasks/generate_combined_pdf.ex` (new file)

**Changes:**

Create a new mix task that:
1. Accepts command-line arguments as comma-delimited item identifiers
2. Queries the database for line items belonging to those items
3. Sorts by item identifier and line item identifier
4. Combines the PDFs using ghostscript (same approach as `generate_receipts`)
5. Outputs to `combined_receipts_{min}_to_{max}.pdf` where min/max are the range of identifiers

```elixir
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
      {num, ""} when num > 0 -> num
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
```

**Testing:**

1. Test with valid item identifiers: `mix generate_combined_pdf 101,103`
2. Test with non-existent item identifiers: `mix generate_combined_pdf 999999`
3. Test with mixed valid/invalid: `mix generate_combined_pdf 101,invalid,103`
4. Test with no arguments: `mix generate_combined_pdf`
5. Test with whitespace: `mix generate_combined_pdf "101, 103, 105"`
6. Verify the generated PDF contains only the specified items in correct order
7. Verify warnings are shown for missing identifiers

**Commit message:** `Add mix task for generating combined PDF with specified item IDs`

---

### Step 2: Update CLAUDE.md documentation with new mix task

**Files to modify:**

- `.claude/CLAUDE.md`

**Changes:**

Add the new mix task to the "Commands > Development" section and update the "Mix Tasks" section with usage examples.

In the Commands > Development section, add:
```markdown
- `mix generate_combined_pdf <item_ids>` - Generate combined PDF for specified item IDs (comma-delimited)
```

In the Mix Tasks section, update the description to:
```markdown
Mix tasks for this project follow the pattern `mix task_name` and are used for processing auction item data:

- `mix process_auction_items` - Process CSV files and save to database with change detection
- `mix generate_receipts` - Generate PDF and HTML receipts for all items from database, plus a combined PDF (combined_receipts.pdf)
- `mix generate_receipt <item_id>` - Generate fresh HTML and PDF for one item from database
- `mix regenerate_receipt_pdf <item_id>` - Regenerate PDF from existing edited HTML
- `mix generate_combined_pdf <item_ids>` - Generate combined PDF for specified item IDs (e.g., `mix generate_combined_pdf 101,103,105`)
- `mix migrate_json_to_db` - One-time migration from JSON files to database
```

**Testing:**

1. Verify the documentation is clear and accurate
2. Confirm the example command is correct

**Commit message:** `Update CLAUDE.md documentation with new mix task`

---

## Implementation Complete

After completing both steps, users will be able to generate custom combined PDFs with:

```bash
mix generate_combined_pdf 101,103,105
```

The output will be saved as `receipts/pdf/combined_receipts_101_to_105.pdf` (filename includes the range of item identifiers).
