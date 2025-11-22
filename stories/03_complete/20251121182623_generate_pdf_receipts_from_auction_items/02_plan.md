# Implementation Plan: Generate PDF Receipts from Auction Items

## Progress Checklist

- [x] Step 1: Add ChromicPDF dependency
- [x] Step 2: Copy logo and create priv directory structure
- [x] Step 3: Create EEx receipt template from HTML design
- [x] Step 4: Create Receipts.ReceiptGenerator module
- [x] Step 5: Create mix generate_receipts task

## Overview

Convert the completed HTML receipt design into a dynamic EEx template and integrate ChromicPDF to generate PDF receipts for all auction items. The system will read auction item data from JSON files, render them using the template, and output professional PDF receipts.

## Key Design Decisions

**PDF Generation Library:**
- Using ChromicPDF instead of alternatives like Puppeteer or wkhtmltopdf
- ChromicPDF uses headless Chrome/Chromium for accurate HTML/CSS rendering
- Supports modern CSS including Tailwind classes used in the design

**Template Approach:**
- Convert HTML to EEx template in `priv/templates/receipt.html.eex`
- Use inline Tailwind CSS via CDN (same as original design)
- Keep template structure identical to approved HTML design
- Logo will be embedded using data URI or served from priv directory

**Data Flow:**
1. Mix task reads JSON files from `db/auction_items/json/`
2. Parse JSON into `Receipts.AuctionItem` structs
3. ReceiptGenerator renders EEx template with item data
4. ChromicPDF converts rendered HTML to PDF
5. Output PDFs to `receipts/` directory named `receipt_<item_id>.pdf`

**Field Formatting:**
- fair_market_value: Format as currency with commas (e.g., $1,200.00)
- description: Already HTML-formatted in JSON, render as-is
- Handle empty/nil fields gracefully with defaults

## Implementation Steps

### Step 1: Add ChromicPDF dependency

**Files to modify:**

- `mix.exs`

**Changes:**

Add ChromicPDF to the dependencies list:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:nimble_csv, "~> 1.2"},
    {:ecto, "~> 3.11"},
    {:req, "~> 0.5.0"},
    {:dotenvy, "~> 0.8.0"},
    {:chromic_pdf, "~> 1.18"}
  ]
end
```

After modifying, run:
```bash
mix deps.get
mix deps.compile
```

**Test:**

Verify dependency is installed:
```bash
mix deps | grep chromic_pdf
```

**Commit message:** `Add ChromicPDF dependency for PDF generation`

---

### Step 2: Copy logo and create priv directory structure

**Files to create:**

- `priv/static/angel_charity_logo.svg`
- `priv/templates/` (directory)
- `receipts/` (directory)

**Changes:**

1. Create directory structure:
```bash
mkdir -p priv/static
mkdir -p priv/templates
mkdir -p receipts
```

2. Copy logo from completed story:
```bash
cp stories/03_complete/20251121182616_design_html_receipt_template/angel_charity_logo.svg priv/static/
```

3. Create `.gitkeep` files to ensure directories are tracked:
```bash
touch receipts/.gitkeep
```

**Test:**

Verify files exist:
```bash
ls -la priv/static/angel_charity_logo.svg
ls -la priv/templates/
ls -la receipts/
```

**Commit message:** `Create priv directory structure and copy logo`

---

### Step 3: Create EEx receipt template from HTML design

**Files to create:**

- `priv/templates/receipt.html.eex`
- `test/receipts/receipt_generator_test.exs` (basic structure, full tests in next step)

**Changes:**

Convert the HTML design to EEx template. Replace static content with dynamic variables:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Angel Charity - Auction Receipt</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @media print {
      body {
        padding: 0;
      }
      @page {
        margin: 0.5in;
        size: letter;
      }
    }
  </style>
</head>
<body class="p-8">
  <div class="max-w-3xl mx-auto p-8">
    <!-- Header Section with Logo -->
    <div class="mb-6 text-center">
      <div class="mb-4 flex justify-center">
        <img src="<%= @logo_path %>" alt="Angel Charity for Children Logo" class="w-32 h-auto">
      </div>

      <div>
        <h2 class="text-xl font-semibold">2025 Angel Ball Silent Auction</h2>
        <p class="text-gray-600">December 13, 2025</p>
      </div>
    </div>

    <!-- Auction Item Details Section -->
    <div class="mb-6">
      <div class="flex justify-between items-center mb-4 pb-2 border-b border-gray-300">
        <h3 class="text-lg font-semibold">Auction Item Details</h3>
        <p class="text-sm text-gray-600 font-normal">Item #<%= @item.item_id %></p>
      </div>

      <div class="mb-4">
        <h4 class="text-xl font-bold"><%= @item.title %></h4>
      </div>

      <div class="grid grid-cols-2 gap-6">
        <div>
          <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Description</h5>
          <div class="text-gray-800 text-sm">
            <%= raw(@item.description) %>
          </div>
        </div>

        <div class="space-y-4">
          <div>
            <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Fair Market Value</h5>
            <p class="text-lg font-bold"><%= @formatted_value %></p>
          </div>

          <%= if @item.notes != "" do %>
          <div>
            <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Special Notes</h5>
            <p class="text-sm text-gray-800"><%= @item.notes %></p>
          </div>
          <% end %>

          <%= if @item.expiration_notice != "" do %>
          <div>
            <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Expiration</h5>
            <p class="text-sm text-gray-800"><%= @item.expiration_notice %></p>
          </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Receipt Acknowledgment Section -->
    <div class="mt-8 pt-6 border-t border-gray-300">
      <h3 class="text-lg font-semibold mb-4">Receipt Acknowledgment</h3>

      <div class="grid grid-cols-12 gap-4">
        <div class="col-span-5">
          <label class="block text-sm font-semibold text-gray-700 mb-2">Printed Name</label>
          <div class="border-b border-gray-300 pb-1" style="min-height: 40px;"></div>
        </div>

        <div class="col-span-5">
          <label class="block text-sm font-semibold text-gray-700 mb-2">Signature</label>
          <div class="border-b border-gray-300 pb-1" style="min-height: 40px;"></div>
        </div>

        <div class="col-span-2">
          <label class="block text-sm font-semibold text-gray-700 mb-2">Date</label>
          <div class="border-b border-gray-300 pb-1" style="min-height: 40px;"></div>
        </div>
      </div>

      <div class="mt-8 text-center text-sm text-gray-600">
        <p>Thank you for supporting Angel Charity for Children!</p>
        <p class="mt-2 text-xs">3132 N. Swan Rd., Tucson, Arizona 85712</p>
        <p class="text-xs">520-326-3686 | info@AngelCharity.org</p>
      </div>
    </div>
  </div>
</body>
</html>
```

Create basic test structure (full tests will be added with the module):

```elixir
defmodule Receipts.ReceiptGeneratorTest do
  use ExUnit.Case
  alias Receipts.ReceiptGenerator

  describe "template rendering" do
    # Tests will be added in next step
  end
end
```

**Test:**

Verify template file exists:
```bash
ls -la priv/templates/receipt.html.eex
```

**Commit message:** `Create EEx receipt template from HTML design`

---

### Step 4: Create Receipts.ReceiptGenerator module

**Files to create:**

- `lib/receipts/receipt_generator.ex`

**Files to modify:**

- `test/receipts/receipt_generator_test.exs`

**Changes:**

Create the ReceiptGenerator module with functions to render templates and generate PDFs:

```elixir
defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  @template_path "priv/templates/receipt.html.eex"
  @logo_path "priv/static/angel_charity_logo.svg"

  def generate_pdf(auction_item, output_path) do
    html = render_html(auction_item)
    ChromicPDF.print_to_pdf({:html, html}, output: output_path)
  end

  def render_html(auction_item) do
    template = File.read!(@template_path)

    assigns = [
      item: auction_item,
      formatted_value: format_currency(auction_item.fair_market_value),
      logo_path: get_logo_data_uri()
    ]

    EEx.eval_string(template, assigns)
  end

  defp format_currency(value) when is_integer(value) do
    dollars = div(value, 1)
    cents = 0

    whole_part =
      dollars
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    "$#{whole_part}.#{String.pad_leading(Integer.to_string(cents), 2, "0")}"
  end

  defp get_logo_data_uri do
    logo_content = File.read!(@logo_path)
    encoded = Base.encode64(logo_content)
    "data:image/svg+xml;base64,#{encoded}"
  end
end
```

Add comprehensive tests in `test/receipts/receipt_generator_test.exs`:

```elixir
defmodule Receipts.ReceiptGeneratorTest do
  use ExUnit.Case
  alias Receipts.ReceiptGenerator
  alias Receipts.AuctionItem

  describe "render_html/1" do
    test "renders receipt template with auction item data" do
      item = AuctionItem.new(%{
        item_id: 103,
        title: "One Year Monthly Landscaping Services",
        description: "<p>Professional landscaping services.</p>",
        fair_market_value: 1200,
        notes: "Good for Tucson area.",
        expiration_notice: "No expiration date."
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "Item #103"
      assert html =~ "One Year Monthly Landscaping Services"
      assert html =~ "<p>Professional landscaping services.</p>"
      assert html =~ "$1,200.00"
      assert html =~ "Good for Tucson area."
      assert html =~ "No expiration date."
    end

    test "handles empty notes field" do
      item = AuctionItem.new(%{
        item_id: 104,
        title: "Test Item",
        description: "<p>Test description</p>",
        fair_market_value: 500,
        notes: "",
        expiration_notice: ""
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "Test Item"
      refute html =~ "Special Notes"
      refute html =~ "Expiration"
    end

    test "formats large currency values with commas" do
      item = AuctionItem.new(%{
        item_id: 999,
        title: "Expensive Item",
        description: "<p>Very valuable</p>",
        fair_market_value: 25000
      })

      html = ReceiptGenerator.render_html(item)

      assert html =~ "$25,000.00"
    end
  end

  describe "generate_pdf/2" do
    setup do
      output_dir = "test/tmp"
      File.mkdir_p!(output_dir)
      on_exit(fn -> File.rm_rf!(output_dir) end)
      %{output_dir: output_dir}
    end

    test "generates PDF file", %{output_dir: output_dir} do
      item = AuctionItem.new(%{
        item_id: 103,
        title: "Test Item",
        description: "<p>Test description</p>",
        fair_market_value: 1200
      })

      output_path = Path.join(output_dir, "test_receipt.pdf")
      {:ok, _} = ReceiptGenerator.generate_pdf(item, output_path)

      assert File.exists?(output_path)
      assert File.stat!(output_path).size > 0
    end
  end
end
```

**Test:**

Run tests to verify implementation:
```bash
mix test test/receipts/receipt_generator_test.exs
```

**Commit message:** `Create ReceiptGenerator module for rendering and PDF generation`

---

### Step 5: Create mix generate_receipts task

**Files to create:**

- `lib/mix/tasks/generate_receipts.ex`

**Files to modify:**

- `test/mix/tasks/generate_receipts_test.exs` (create new test file)

**Changes:**

Create Mix task to orchestrate batch PDF generation:

```elixir
defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.AuctionItem
  alias Receipts.ReceiptGenerator

  @shortdoc "Generate PDF receipts for all auction items"

  @json_dir "db/auction_items/json"
  @output_dir "receipts"

  def run(_args) do
    Mix.shell().info("Generating receipts...")

    File.mkdir_p!(@output_dir)

    items = load_auction_items()
    total = length(items)

    Mix.shell().info("Found #{total} auction items")

    results =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        generate_receipt(item, index, total)
      end)

    successful = Enum.count(results, fn result -> result == :ok end)
    failed = total - successful

    Mix.shell().info("\nGeneration complete!")
    Mix.shell().info("Successfully generated: #{successful} receipts")

    if failed > 0 do
      Mix.shell().error("Failed: #{failed} receipts")
    end
  end

  defp load_auction_items do
    @json_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.flat_map(fn filename ->
      path = Path.join(@json_dir, filename)
      {:ok, content} = File.read(path)
      {:ok, items_data} = Jason.decode(content)

      Enum.map(items_data, fn item_data ->
        AuctionItem.new(item_data)
      end)
    end)
  end

  defp generate_receipt(item, index, total) do
    output_path = Path.join(@output_dir, "receipt_#{item.item_id}.pdf")

    Mix.shell().info("[#{index}/#{total}] Generating receipt for item ##{item.item_id}...")

    case ReceiptGenerator.generate_pdf(item, output_path) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Failed to generate receipt for item ##{item.item_id}: #{inspect(reason)}")
        :error
    end
  end
end
```

Create test file `test/mix/tasks/generate_receipts_test.exs`:

```elixir
defmodule Mix.Tasks.GenerateReceiptsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @test_json_dir "test/tmp/json"
  @test_output_dir "test/tmp/receipts"

  setup do
    File.mkdir_p!(@test_json_dir)
    File.mkdir_p!(@test_output_dir)

    test_data = [
      %{
        item_id: 1,
        title: "Test Item 1",
        description: "<p>Description 1</p>",
        fair_market_value: 100
      },
      %{
        item_id: 2,
        title: "Test Item 2",
        description: "<p>Description 2</p>",
        fair_market_value: 200
      }
    ]

    json_path = Path.join(@test_json_dir, "test_items.json")
    File.write!(json_path, Jason.encode!(test_data))

    original_json_dir = Application.get_env(:receipts, :json_dir, "db/auction_items/json")
    original_output_dir = Application.get_env(:receipts, :output_dir, "receipts")

    Application.put_env(:receipts, :json_dir, @test_json_dir)
    Application.put_env(:receipts, :output_dir, @test_output_dir)

    on_exit(fn ->
      File.rm_rf!(@test_json_dir)
      File.rm_rf!(@test_output_dir)
      Application.put_env(:receipts, :json_dir, original_json_dir)
      Application.put_env(:receipts, :output_dir, original_output_dir)
    end)

    :ok
  end

  test "generates receipts for all auction items" do
    output = capture_io(fn ->
      Mix.Tasks.GenerateReceipts.run([])
    end)

    assert output =~ "Found 2 auction items"
    assert output =~ "Successfully generated: 2 receipts"

    assert File.exists?(Path.join(@test_output_dir, "receipt_1.pdf"))
    assert File.exists?(Path.join(@test_output_dir, "receipt_2.pdf"))
  end
end
```

Note: The test will need the Mix task to be modified to support configurable directories. Update the Mix task to use application config:

```elixir
# In Mix.Tasks.GenerateReceipts
@json_dir Application.compile_env(:receipts, :json_dir, "db/auction_items/json")
@output_dir Application.compile_env(:receipts, :output_dir, "receipts")
```

**Test:**

Run the Mix task test:
```bash
mix test test/mix/tasks/generate_receipts_test.exs
```

Then test with real data:
```bash
mix generate_receipts
```

Verify PDFs are created:
```bash
ls -la receipts/
```

**Commit message:** `Create mix generate_receipts task for batch PDF generation`

---

## Completion Criteria

- [ ] ChromicPDF dependency installed and working
- [ ] Logo and directory structure in place
- [ ] EEx template matches HTML design exactly
- [ ] ReceiptGenerator module renders templates correctly
- [ ] PDF generation works for single items
- [ ] Mix task generates all receipts successfully
- [ ] All tests pass
- [ ] Generated PDFs match the visual design

## Notes

- Currency formatting: Using integer values (cents), displaying as dollars with commas
- Logo embedding: Using base64 data URI to avoid path issues in PDF generation
- Error handling: Mix task continues processing even if individual items fail
- The description field contains HTML and is rendered using `raw/1` helper
