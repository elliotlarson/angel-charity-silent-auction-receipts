# Mix Task to Report Auction Data Changes Between CSV Imports

## Context

The auction items source data is stored in CSV files with date stamps (e.g., `20251205_auction_items.csv`, `20251210_auction_Items.csv`, `20251212_auction_items.csv`) in the `db/auction_items_source_data/` directory.

As new CSV files are imported over time, we need a way to see what changed between consecutive imports to track:

- New auction items added
- Deleted auction items
- Updates to existing items (price changes, title changes, description changes)

## Requirements

Create a Mix task `mix report_import_data_changes` that:

1. **Finds all CSV files** in `db/auction_items_source_data/` directory
2. **Sorts them chronologically** by the date stamp in the filename
3. **Compares consecutive CSVs** (e.g., 20251205 → 20251210, then 20251210 → 20251212)
4. **Generates a report** showing changes between each pair

## Report Format

For each comparison (e.g., "Changes from 20251205 to 20251210"):

### New Items

Display: Qtego #, Title, Price

```
NEW: SA123: Item Title ($1,000.00)
```

### Deleted Items

Display: Qtego #, Title, Price

```
DELETED: SA456: Item Title ($500.00)
```

### Updated Items

Display: Qtego #, Title, Price, followed by bulleted list of what changed

```
UPDATED: SA789: Item Title ($750.00)
  • Price changed from: $700.00, to: $750.00
  • Title changed from: "Old Title", to: "New Title"
  • Description changed
```

## Technical Details

- CSV files are parsed using NimbleCSV
- CSV format has a summary row (row 1), headers (row 2), then data rows
- Key columns: "Qtego #", "Item Donated Title", "Value", "Detailed Item Description"
- The `Qtego #` is the unique identifier for each auction item
- Changes are detected by comparing normalized values (trimmed whitespace)

## Success Criteria

- Mix task runs without errors
- Report accurately identifies new, deleted, and updated items
- Report format is clear and easy to read
- Handles multiple CSV comparisons in chronological order
- Works with current CSV files and will work as new ones are added
