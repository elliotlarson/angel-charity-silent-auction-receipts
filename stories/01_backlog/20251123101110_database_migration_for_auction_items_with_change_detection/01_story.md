# Database Migration for Auction Items with Change Detection

## Problem Statement

Currently, auction items are processed from CSV files and stored as JSON files. This creates several issues:

### Current Workflow Issues

1. **No source of truth** - JSON files are intermediate artifacts, not a proper data store
2. **No change detection** - Re-running CSV processing duplicates work even if data hasn't changed
3. **Inefficient AI processing** - Every run processes all items, even unchanged ones, wasting API calls
4. **File selection confusion** - Multiple dated JSON files in a directory require manual selection
5. **No historical tracking** - Can't see what changed between CSV imports
6. **Wasted resources** - Re-processing unchanged items wastes time and API costs

### Current Process

```
CSV → process_auction_items → JSON file → generate_receipts → PDFs
                                  ↓
                            (lost after use)
```

### Desired Process

```
CSV → process_auction_items → Database (source of truth) → generate_receipts → PDFs
         ↓
    Detect changes via hash
    Only process changed items
```

## Desired Outcome

Migrate to a database-backed system with intelligent change detection:

### Database as Source of Truth

- Use SQLite database (via Ecto) to store auction items
- Database persists across runs
- Single source of truth for all auction item data
- No more JSON files to manage

### Change Detection

- Hash each CSV row (SHA256) before processing
- Compare hash with database to detect changes
- Only process items that have changed
- Skip AI processing for unchanged items (saves time and API costs)

### Data Retention

- Store original CSV line in database for reference
- Keep raw data alongside processed fields
- Enable debugging and data validation
- Track when records were created/updated

### Updated Workflow

1. **First run**: Process all items, save to database
2. **Subsequent runs**:
   - Check hash of each CSV row
   - Skip unchanged items (no AI processing needed)
   - Only process/update changed items
   - Report skipped vs processed counts

### Benefits

- **Faster subsequent runs** - Only process what changed
- **Lower API costs** - Skip AI processing for unchanged data
- **Single source of truth** - Database, not scattered JSON files
- **Change tracking** - Know what changed between imports
- **Better data integrity** - Proper database with constraints
- **Simplified workflow** - No file selection for generate_receipts

## Expected Outcome

- SQLite database with `auction_items` table
- Migration from existing JSON files (one-time)
- Change detection via SHA256 hash comparison
- `mix process_auction_items` updates database (not JSON)
- `mix generate_receipts` reads from database (no file selection needed)
- Dramatically faster re-processing of CSV files
- All tests updated and passing
