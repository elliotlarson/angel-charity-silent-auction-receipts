# Support new CSV format for auction items

## Problem Statement

The auction items data source has changed to a new CSV format with different column headers. When processing the new CSV file (20251205_auction_items.csv), the system deleted all 122 existing items and 137 line items instead of importing the data.

**Root Cause:**
The `Mix.Tasks.ProcessAuctionItems` module expects specific column headers from the old format:
- `ITEM ID`
- `15 CHARACTER DESCRIPTION`
- `100 CHARACTER DESCRIPTION`
- `1500 CHARACTER DESCRIPTION (OPTIONAL)`
- `FAIR MARKET VALUE`
- `CATEGORIES (OPTIONAL)`

The new CSV format uses different headers:
- `Tag #` (maps to ITEM ID)
- `Item Donated Title` (maps to 100 CHARACTER DESCRIPTION)
- `Detailed Item Description` (maps to 1500 CHARACTER DESCRIPTION)
- `Value` (maps to FAIR MARKET VALUE)
- `Category` (maps to CATEGORIES)
- No equivalent to 15 CHARACTER DESCRIPTION (short_title)

**Impact:**
- The code couldn't find matching columns in the new CSV
- Zero items were processed from the CSV file
- The cleanup logic deleted all existing database records thinking they were removed from the CSV
- We lost all previously imported auction item data

**Requirements:**
1. Support both old and new CSV formats
2. Detect which format is being used based on headers
3. Map new column names to existing field names
4. Handle missing columns gracefully (e.g., short_title doesn't exist in new format)
5. Preserve existing change detection and AI processing functionality
