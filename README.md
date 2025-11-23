# Receipts

Generating silent auction receipts for Angel Charity's 2025 Angel Ball Silent Auction.

## Quick Start Workflow

When you receive a new CSV file from Angel Charity, follow these steps:

1. **Place CSV file** in `db/auction_items/csv/`
2. **Process CSV to database** with AI extraction:

   ```bash
   mix process_auction_items
   ```

   - Select the CSV file from the list
   - AI will extract expiration dates and special notes
   - Changes detected automatically (unchanged items skipped)
   - Data saved to SQLite database

3. **Generate PDF and HTML receipts**:

   ```bash
   mix generate_receipts
   ```

   - Reads all items from database
   - Generates PDFs in `receipts/pdf/`
   - Generates HTML in `receipts/html/`
   - Files named: `receipt_<id>_<short_title>.[pdf|html]`

4. **Review outputs**:
   - Check `receipts/pdf/` for printable PDFs
   - Check `receipts/html/` for web-viewable versions

## Processing Auction Items

This project includes a Mix task for processing auction item CSV files and storing them in a SQLite database with AI-powered field extraction and intelligent change detection.

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
   - Compute SHA256 hash of each CSV row for change detection
   - Check database for existing items
   - Skip unchanged items (saves AI processing time and cost)
   - Process new or changed items with AI extraction
   - Filter out placeholder rows (items with zero or empty ID or Fair Market Value)
   - **Use AI to extract expiration dates and special notes from descriptions**
   - Show progress for each item processed
4. Save the processed data to SQLite database in `db/receipts_dev.db`

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
Processing 20251121_auction_items.csv...
[1/137] Created item #103
[2/137] Created item #104
[3/137] Skipped item #105 (unchanged)
...

Summary:
  New items: 5
  Updated items: 2
  Skipped (unchanged): 130

Processing complete!
Total items in database: 137
```

## Generating Receipts

After processing the CSV to the database, generate PDF and HTML receipts:

```bash
mix generate_receipts
```

The task will:

1. Read all auction items from the database
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
Generating receipts for 137 auction items...
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

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/receipts/anthropic_client_test.exs
```

### Updating API Test Fixtures

The test suite uses real API response fixtures to avoid making live API calls during tests. If the Anthropic API format changes, you can re-capture the fixtures:

```bash
mix run scripts/capture_api_responses.exs
```

This script:
- Makes real API calls to Anthropic (requires `ANTHROPIC_API_KEY` in `.env`)
- Captures successful and error responses
- Saves them as fixtures in `test/fixtures/`
- Allows tests to run offline with real API response structures

The fixtures are used by the test suite to ensure tests are fast, reliable, and don't require an API key.
