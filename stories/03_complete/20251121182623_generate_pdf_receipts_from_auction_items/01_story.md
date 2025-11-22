# Generate PDF receipts from auction items

We need to convert the HTML receipt design into an EEx template and use it to generate PDF receipts for all auction items from the JSON data files.

The design is located at: stories/03_complete/20251121182616_design_html_receipt_template/index.html

## Requirements

**Template System:**

- Convert the static HTML receipt design into an EEx template
- Template should accept auction item data as variables
- Support dynamic data insertion for all receipt fields
- Maintain the exact visual design from the HTML mockup

**PDF Generation:**

- Use ChromicPDF to render HTML templates as PDFs
- Generate one receipt PDF per auction item
- Read auction item data from JSON files in `db/auction_items/json/`
- Output PDFs to `receipts/` directory
- Name PDFs by item ID (e.g., `receipt_103.pdf`)

**Mix Task:**

- Create a Mix task `mix generate_receipts` to batch generate all receipts
- Task should:
  - Read all JSON files from `db/auction_items/json/`
  - Parse auction items into `Receipts.AuctionItem` structs
  - Generate a PDF receipt for each item
  - Display progress and summary (e.g., "Generated 137 receipts")

**Data Integration:**

- Use existing `Receipts.AuctionItem` struct
- Format currency values (fair_market_value as $X,XXX)
- Handle missing or empty fields gracefully
- Include all auction item fields from the JSON data

## Technical Approach

1. Add ChromicPDF dependency
2. Create EEx template from HTML design
3. Create `Receipts.ReceiptGenerator` module to handle rendering and PDF generation
4. Create Mix task to orchestrate batch generation
5. Add tests for template rendering and PDF generation

## Deliverable

A working system that generates professional PDF receipts for all auction items, with a simple command: `mix generate_receipts`
