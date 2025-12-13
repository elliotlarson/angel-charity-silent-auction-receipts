# Receipts

Generating silent auction receipts for Angel Charity's 2025 Angel Ball Silent Auction.

## Quick Start Workflow

When you receive a new CSV file from Angel Charity, follow these steps:

1. **Place CSV file** in `db/auction_items_source_data/`

2. **(Optional) Review changes** from previous CSV:

   ```bash
   mix report_import_data_changes
   ```

   - Shows new, deleted, and updated items
   - Helps verify data before processing
   - Colored output for easy reading

3. **Process CSV to database** with AI extraction:

   ```bash
   mix process_auction_items
   ```

   - Select the CSV file from the list
   - AI will extract expiration dates and special notes
   - Changes detected automatically (unchanged items skipped)
   - Data saved to SQLite database

4. **Generate PDF and HTML receipts**:

   ```bash
   mix generate_receipts
   ```

   - Reads all line items from database
   - Generates PDFs in `receipts/pdf/`
   - Generates HTML in `receipts/html/`
   - Files named: `receipt_<item_id>_<short_title>.[pdf|html]` (single line item)
   - Or: `receipt_<item_id>_<n>_of_<total>_<short_title>.[pdf|html]` (multiple line items)

5. **Sync to DropBox** (for sharing with collaborators):

   ```bash
   mix sync_receipts
   ```

   - Syncs `receipts/pdf/` to shared DropBox folder
   - Uses rsync for efficient incremental transfers
   - Removes files from DropBox that no longer exist locally

6. **Review outputs**:
   - Check `receipts/pdf/` for printable PDFs
   - Check `receipts/html/` for web-viewable versions

## Processing Auction Items

This project uses a normalized Item/LineItem data model where:

- **Items** represent unique auction packages (e.g., Item #139)
- **LineItems** represent individual offerings within an item (e.g., different package options)
- Some items have multiple line items (e.g., hotel packages with different add-ons)

The Mix task processes auction item CSV files and stores them in a SQLite database with AI-powered field extraction and intelligent change detection.

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

1. Display a list of available CSV files in `db/auction_items_source_data/`
2. Prompt you to select a file by number
3. Process the CSV file with intelligent change detection:
   - Creates new items and line items
   - Updates existing line items if CSV data changed (with AI reprocessing)
   - Skips unchanged line items (saves AI processing time and cost)
   - Deletes line items no longer in CSV
   - Deletes items that have no line items
   - Computes SHA256 hash of each CSV row for change detection
   - Filters out placeholder rows (items with zero or empty ID or Fair Market Value)
   - **Uses AI to extract expiration dates and special notes from descriptions**
   - Shows progress for each item processed
4. Saves the processed data to SQLite database in `db/receipts_dev.db`

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

### Data Model

**Items table:**

- `item_identifier` - Business ID from CSV (e.g., 103, 139)

**LineItems table (one row per CSV row):**

- `identifier` - Position within item (1, 2, 3 for multiple line items)
- `short_title` - 15 character description
- `title` - 100 character description
- `description` - 1500 character description (cleaned by AI if processing enabled)
- `fair_market_value` - Fair market value
- `categories` - Item categories
- `expiration_notice` - Expiration dates/notices extracted by AI
- `notes` - Special instructions extracted by AI
- `csv_row_hash` - SHA256 hash for change detection
- `csv_raw_line` - Original CSV row for audit

### Example

```bash
$ mix process_auction_items
Available CSV files:
  1. 20251121_auction_items.csv
Select file number: 1
Processing 20251121_auction_items.csv...
[1/137] Created line item for #103
[2/137] Created line item for #104
[3/137] Skipped line item for #105 (unchanged)
[4/137] Updated line item for #106
...

Summary:
  New items: 3
  New line items: 5
  Updated line items: 2
  Skipped (unchanged): 127
  Deleted items: 0
  Deleted line items: 0

Processing complete!
Total items in database: 122
Total line items in database: 137
```

## Reporting CSV Changes

Track changes between consecutive CSV imports to understand what was added, removed, or updated:

```bash
mix report_import_data_changes
```

The task will:

1. Find all CSV files in `db/auction_items_source_data/`
2. Sort them chronologically by filename date
3. Compare each consecutive pair of files
4. Generate a detailed report showing:
   - **New items** - Items added in the newer file
   - **Deleted items** - Items removed from the newer file
   - **Updated items** - Items with price, title, or description changes

### Report Format

The report uses color coding for easy reading:

- **Item #XXX** - Yellow
- **Item titles** - White
- **Prices** - Gray
- **Field labels** - Cyan
- **Changed values** - Gray

### Example Output

```
================================================================================
Changes from 20251205_auction_items.csv to 20251210_auction_items.csv
--------------------------------------------------------------------------------

NEW ITEMS (3)
--------------------------------------------------------------------------------
Item #270: Weekend Getaway Package ($1,500.00)
Item #271: Golf Foursome ($800.00)
Item #272: Wine Collection ($2,400.00)

DELETED ITEMS (1)
--------------------------------------------------------------------------------
Item #123: Old Item Package ($500.00)

UPDATED ITEMS (5)
--------------------------------------------------------------------------------
Item #103: One Year Monthly Landscaping Services ($1,200.00)
  • Price changed
    • from: $1,000.00
    • to: $1,200.00
  • Title changed
    • from: "Landscaping Services"
    • to: "One Year Monthly Landscaping Services"

Item #105: Design Consultation ($2,069.00)
  • Description changed

--------------------------------------------------------------------------------
Summary: 3 new, 1 deleted, 5 updated
================================================================================
```

This is useful for:

- Understanding what changed between CSV versions
- Verifying data updates before processing
- Tracking auction item modifications over time

## Generating Receipts

After processing the CSV to the database, generate PDF and HTML receipts:

```bash
mix generate_receipts
```

The task will:

1. Read all line items from the database (one receipt per line item)
2. Generate a PDF receipt for each line item in `receipts/pdf/`
3. Generate an HTML receipt for each line item in `receipts/html/`
4. Display progress for each receipt
5. Show a summary when complete

### Output Structure

```
receipts/
  pdf/
    receipt_103_landscaping.pdf              # Single line item
    receipt_139_1_of_3_ac_hotel.pdf          # Multiple line items
    receipt_139_2_of_3_ac_hotel_el_charro.pdf
    receipt_139_3_of_3_ac_hotel_forbes.pdf
    ...
  html/
    receipt_103_landscaping.html
    receipt_139_1_of_3_ac_hotel.html
    ...
```

**Filename format:**

- Single line item: `receipt_<item_id>_<short_title>.[pdf|html]`
- Multiple line items: `receipt_<item_id>_<n>_of_<total>_<short_title>.[pdf|html]`

### Example

```bash
$ mix generate_receipts
Generating receipts for 137 line items...
[1/137] Generating receipt for item #103 (line item 1)...
[2/137] Generating receipt for item #104 (line item 2)...
[3/137] Generating receipt for item #139 (line item 38)...
...
[137/137] Generating receipt for item #240 (line item 137)...

Generation complete!
Successfully generated: 137 receipts
```

### Regenerating Individual Receipts

After generating receipts, you can regenerate individual line items:

**Regenerate from database (fresh HTML + PDF):**

```bash
mix generate_receipt <line_item_id>
```

This reads the current data from the database and generates fresh HTML and PDF files. Useful when you've updated a line item's data in the database.

**Note:** Use the line item's database ID, not the item identifier. You can find line item IDs by querying the database or checking the filenames.

**Regenerate PDF from edited HTML:**

```bash
mix regenerate_receipt_pdf <item_id>
```

This regenerates only the PDF from an existing HTML file. Useful when you've manually edited the HTML to adjust layout or formatting.

**Example workflow for manual HTML editing:**

```bash
# 1. Edit the HTML file to fix layout
vim receipts/html/receipt_139_2_of_3_el_charro.html

# 2. Regenerate just the PDF from edited HTML
$ mix regenerate_receipt_pdf 139
Reading HTML from: receipts/html/receipt_139_2_of_3_el_charro.html
Generating PDF to: receipts/pdf/receipt_139_2_of_3_el_charro.pdf
Successfully regenerated PDF for item #139
```

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
