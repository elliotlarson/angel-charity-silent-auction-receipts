# Receipts

Generating silent auction receipts for Angel Charity's 2025 Angel Ball Silent Auction.

## Quick Start Workflow

When you receive a new CSV file from Angel Charity, follow these steps:

1. **Place CSV file** in `db/auction_items/csv/`
2. **Process CSV to JSON** with AI extraction:
   ```bash
   mix process_auction_items
   ```
   - Select the CSV file from the list
   - AI will extract expiration dates and special notes
   - Output saved to `db/auction_items/json/`

3. **Generate PDF and HTML receipts**:
   ```bash
   mix generate_receipts
   ```
   - Reads all JSON files from `db/auction_items/json/`
   - Generates PDFs in `receipts/pdf/`
   - Generates HTML in `receipts/html/`
   - Files named: `receipt_<id>_<short_title>.[pdf|html]`

4. **Review outputs**:
   - Check `receipts/pdf/` for printable PDFs
   - Check `receipts/html/` for web-viewable versions

## Processing Auction Items

This project includes a Mix task for converting auction item CSV files to JSON format with AI-powered field extraction.

### Setup

Create a `.env` file in the project root with your Anthropic API key:

```bash
ANTHROPIC_API_KEY=your-api-key-here
```

The `.env` file is automatically loaded when running the Mix task.

### Usage

```bash
# Process with AI extraction (default)
mix process_auction_items

# Skip AI processing
mix process_auction_items --skip-ai-processing
```

The task will:
1. Display a list of available CSV files in `db/auction_items/csv/`
2. Prompt you to select a file by number
3. Process the CSV file:
   - Remove empty lines
   - Filter out placeholder rows (items with zero or empty ID or Fair Market Value)
   - Extract relevant fields from the CSV
   - **Use AI to extract expiration dates and special notes from descriptions**
   - Show progress for each item processed
4. Save the processed data as JSON in `db/auction_items/json/`

### AI Processing

The task uses Claude (Anthropic API) to intelligently extract:

- **Expiration notices** - Dates, validity periods, or time limits
- **Special notes** - Instructions like "call ahead", contact info, restrictions, scheduling requirements
- **Cleaned descriptions** - Original description with expiration and notes removed

**Benefits:**
- ✅ **Cached** - Results are cached, so re-running is instant
- ✅ **Smart** - Understands natural language and context
- ✅ **Graceful** - Falls back to original description if extraction fails
- ✅ **Progress tracking** - Shows "Processed item X/Y (ID: ###)" as it works

### Extracted Fields

The following fields are extracted from each auction item:

- `item_id` - Item ID
- `short_title` - 15 character description
- `title` - 100 character description
- `description` - 1500 character description (cleaned by AI if processing enabled)
- `fair_market_value` - Fair market value
- `categories` - Item categories
- `expiration_notice` - Expiration dates/notices extracted by AI
- `notes` - Special instructions extracted by AI

### Example

```bash
$ mix process_auction_items
Available CSV files:
  1. 20251121_auction_items.csv
Select file number: 1
AI processing enabled - this may take a few minutes...
Processed item 1/137 (ID: 103)
Processed item 2/137 (ID: 104)
Processed item 3/137 (ID: 105)
...
Successfully processed 137 items
Output saved to: db/auction_items/json/20251121_auction_items.json
```

## Generating Receipts

After processing the CSV to JSON, generate PDF and HTML receipts:

```bash
mix generate_receipts
```

The task will:
1. Read all JSON files from `db/auction_items/json/`
2. Generate a PDF receipt for each item in `receipts/pdf/`
3. Generate an HTML receipt for each item in `receipts/html/`
4. Display progress for each receipt
5. Show a summary when complete

### Output Structure

```
receipts/
  pdf/
    receipt_103_landscaping.pdf
    receipt_104_show_stopper.pdf
    ...
  html/
    receipt_103_landscaping.html
    receipt_104_show_stopper.html
    ...
```

Files are named: `receipt_<item_id>_<short_title_in_snake_case>.[pdf|html]`

### Example

```bash
$ mix generate_receipts
Generating receipts...
Found 137 auction items
[1/137] Generating receipt for item #103...
[2/137] Generating receipt for item #104...
...
[137/137] Generating receipt for item #240...

Generation complete!
Successfully generated: 137 receipts
```

### Manually Editing and Regenerating a Receipt

If a receipt is too long and spills onto a second page, you can manually edit the HTML and regenerate just that PDF:

1. **Edit the HTML file** in `receipts/html/receipt_<id>_<title>.html`
   - Reduce font sizes, adjust spacing, or shorten text as needed
   - The HTML uses Tailwind CSS classes for styling

2. **Regenerate the PDF** from the edited HTML:
   ```bash
   mix regenerate_receipt <item_id>
   ```

**Example:**
```bash
# Edit receipts/html/receipt_120_belize.html manually
# Then regenerate just that PDF:
$ mix regenerate_receipt 120
Reading HTML from: receipts/html/receipt_120_belize.html
Generating PDF to: receipts/pdf/receipt_120_belize.pdf
✓ Successfully regenerated PDF for item #120
```

This regenerates only the specified receipt's PDF without affecting any others.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `receipts` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:receipts, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/receipts>.
