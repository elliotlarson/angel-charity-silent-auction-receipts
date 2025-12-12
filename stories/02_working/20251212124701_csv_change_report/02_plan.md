# Implementation Plan: CSV Change Report Mix Task

## Overview

Create a Mix task `mix report_import_data_changes` that compares consecutive CSV files and generates a human-readable report of changes (new items, deleted items, updated items with specific field changes).

## Implementation Steps

### Step 1: Create the Mix Task Module

- [ ] Create `lib/mix/tasks/report_import_data_changes.ex`
- [ ] Define module `Mix.Tasks.ReportImportDataChanges`
- [ ] Add `use Mix.Task` and `@shortdoc`
- [ ] Define NimbleCSV parser (same as in `ProcessAuctionItems`)
- [ ] Create `run/1` function to bootstrap the task

**Files to create:**

- `lib/mix/tasks/report_import_data_changes.ex`

**Acceptance criteria:**

- Task can be invoked with `mix report_import_data_changes`
- Task prints a header message

---

### Step 2: CSV File Discovery and Sorting

- [ ] Implement `list_csv_files/0` to find all CSV files in `db/auction_items_source_data/`
- [ ] Sort files chronologically by extracting date from filename pattern `YYYYMMDD_*`
- [ ] Handle files with different naming patterns (e.g., `auction_Items` vs `auction_items`)
- [ ] Display found files to user with file count

**Implementation details:**

- Use `File.ls/1` to list directory contents
- Filter for `.csv` extension
- Sort by filename (date prefix ensures chronological order)
- Extract date using regex: `~r/^(\d{8})_/`

**Acceptance criteria:**

- All CSV files are discovered
- Files are sorted in chronological order
- User sees list of files that will be compared

---

### Step 3: CSV Parsing Function

- [ ] Create `parse_csv/1` function to parse a single CSV file
- [ ] Handle CSV structure: summary row (row 1), headers (row 2), data rows
- [ ] Extract key fields: Qtego #, Item Donated Title, Value, Detailed Item Description
- [ ] Return a map of `%{qtego_id => %{qtego, title, price, description}}`
- [ ] Normalize values (trim whitespace, handle case sensitivity)

**Implementation details:**

- Skip first row (summary row)
- Use second row as headers
- Find column indices for required fields
- Build map keyed by Qtego # for easy comparison
- Store original values for display in report

**Acceptance criteria:**

- CSV files parse correctly
- Data structure is suitable for comparison
- Empty/missing Qtego # items are skipped

---

### Step 4: Comparison Logic

- [ ] Create `compare_csv_files/2` function that takes two parsed CSV maps
- [ ] Identify new items (in file2, not in file1)
- [ ] Identify deleted items (in file1, not in file2)
- [ ] Identify updated items (in both, but with changes)
- [ ] For updated items, detect which fields changed (price, title, description)
- [ ] Return structured comparison result

**Implementation details:**

```elixir
%{
  new: [%{qtego: "SA123", title: "...", price: "..."}],
  deleted: [%{qtego: "SA456", title: "...", price: "..."}],
  updated: [%{
    qtego: "SA789",
    title: "...",
    price: "...",
    changes: [
      {:price, "$100", "$150"},
      {:title, "Old", "New"},
      {:description, :changed}
    ]
  }]
}
```

**Acceptance criteria:**

- New items correctly identified
- Deleted items correctly identified
- Updated items correctly identified with specific field changes
- Whitespace-only changes are ignored

---

### Step 5: Report Formatting

- [ ] Create `format_report/3` function to generate human-readable output
- [ ] Accept: file1_name, file2_name, comparison_result
- [ ] Format header: "Changes from [file1] to [file2]"
- [ ] Format new items section
- [ ] Format deleted items section
- [ ] Format updated items section with bullet points for changes
- [ ] Use ANSI colors for better readability (optional)

**Report format:**

```
================================================================================
Changes from 20251205_auction_items.csv to 20251210_auction_Items.csv
================================================================================

NEW ITEMS (3)
--------------------------------------------------------------------------------
SA123: One Year Landscaping Service ($1,200.00)
SA124: Original Painting ($2,400.00)
SA125: Design Consultation ($2,069.00)

DELETED ITEMS (1)
--------------------------------------------------------------------------------
SA099: Old Package ($500.00)

UPDATED ITEMS (5)
--------------------------------------------------------------------------------
SA041: Golf Foursome at SaddleBrooke ($1,000.00)
  • Price changed from: $400.00, to: $1,000.00

SA114: Private Suite at Diamondbacks Game ($2,500.00)
  • Title changed from: "Private Suite @ Chase Field", to: "Private Suite at Chase Field"

SA138: Work Space Plus Headshot ($5,063.00)
  • Price changed from: $4,788.00, to: $5,063.00
  • Description changed

================================================================================
Summary: 3 new, 1 deleted, 5 updated
================================================================================
```

**Acceptance criteria:**

- Report is easy to read
- Sections are clearly separated
- All changes are accurately represented
- Summary line shows totals

---

### Step 6: Main Execution Flow

- [ ] In `run/1`, implement the main flow:
  1. List and sort CSV files
  2. Check if at least 2 files exist
  3. For each consecutive pair, compare and generate report
  4. Print reports to console
- [ ] Handle edge cases (no files, only one file)
- [ ] Add error handling for file read/parse errors

**Implementation details:**

- Use `Enum.chunk_every(2, 1, :discard)` to get consecutive pairs
- Process each pair sequentially
- Print separator between reports if multiple comparisons

**Acceptance criteria:**

- Task handles 0, 1, or many CSV files gracefully
- Each comparison is clearly separated
- Errors are reported clearly

---

### Step 7: Testing and Validation

- [ ] Test with current CSV files (20251205, 20251210, 20251212)
- [ ] Verify new item detection (SA270 in 20251212)
- [ ] Verify deleted item detection (SA269 deleted from 20251212)
- [ ] Verify update detection (price changes, title changes)
- [ ] Test with CSV files in different formats
- [ ] Add documentation comments to functions

**Acceptance criteria:**

- All known changes are correctly reported
- No false positives or false negatives
- Code is well-documented

---

## Technical Considerations

### CSV Format Notes

- First row: Summary row with totals (skip this)
- Second row: Headers
- Column names: "Qtego #", "Item Donated Title", "Value", "Detailed Item Description"
- Handle case-insensitive header matching

### Normalization Strategy

- Trim all string values
- For comparison, normalize whitespace (collapse multiple spaces)
- Keep original values for display
- For descriptions, only report "changed" rather than full diff

### Performance

- Should handle ~200-300 items per file efficiently
- Memory usage should be reasonable (load one file at a time if needed)

## Dependencies

- `NimbleCSV` (already in project)
- `Receipts.Config` for directory path (if needed)
- Standard library only

## Future Enhancements (Not in Scope)

- Save report to file instead of console
- Filter by specific Qtego # or category
- Compare non-consecutive files
- Generate HTML or JSON output
- Integration with database to show what changed in DB vs CSV
