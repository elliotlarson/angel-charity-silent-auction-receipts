# Migrate to Item and LineItem data model with has_many relationship

## Problem Statement

The current data model assumes one record per `item_id`, but the CSV actually contains **multiple line items per item**. For example, Item #139 (AC Hotel packages) has 3 different line items:
- Row 38: Hotel room only
- Row 39: Hotel + El Charro dinner
- Row 40: Hotel + El Charro + Forbes

**Current Issues:**

1. **Duplicate item_ids** - 13 items have multiple line items in the CSV (rows with same item_id)
2. **Data loss** - Current system updates the same database record multiple times, only keeping the last one
3. **Wrong model** - `auction_items` table treats each CSV row as independent, ignoring the item/line_item relationship
4. **Confused semantics** - What we call "auction items" are actually "line items" within auction items

### Examples of Duplicate Item IDs (from CSV)

- **Item #139** (3 line items): Rows 38, 39, 40 - AC Hotel packages with different add-ons
- **Item #140** (2 line items): Rows 41, 42 - Joe Bourne performance vs Lil' Luxuries
- **Item #223** (3 line items): Rows 126, 127, 128 - Different home decor shopping options
- Plus 10 more items with duplicates (total 137 line items across ~122 unique item_ids)

### Current Broken Behavior

When processing the CSV:
```
[33/137] Updated item #139  ← Processing row 38
[34/137] Updated item #139  ← Processing row 39 (overwrites row 38!)
[35/137] Updated item #139  ← Processing row 40 (overwrites row 39!)
```

Only the last line item (row 40) is kept in the database.

## Desired Outcome

Implement proper data model with **Items** and **LineItems**:

### Data Model

**Items table** (the package/group):
- `id` - Auto-generated primary key
- `item_id` - Business key from CSV (139, 140, etc.)
- `inserted_at`, `updated_at` - Timestamps

**LineItems table** (the individual offerings):
- `id` - Auto-generated primary key
- `item_id` - Foreign key to items table
- `short_title` - 15 character description
- `title` - 100 character description
- `description` - Full description (HTML)
- `fair_market_value` - Price
- `categories` - Categories
- `notes` - Special instructions (AI extracted)
- `expiration_notice` - Expiration info (AI extracted)
- `csv_row_hash` - SHA256 hash for change detection
- `csv_raw_line` - Original CSV row
- `inserted_at`, `updated_at` - Timestamps

### Relationships

```elixir
# Item has many LineItems
has_many :line_items, Receipts.LineItem

# LineItem belongs to Item
belongs_to :item, Receipts.Item, references: :item_id, foreign_key: :item_id
```

### Migration Strategy

1. **Drop existing data** - Delete current auction_items table
2. **Create new schema** - Items and LineItems tables
3. **Re-import from CSV** - Process CSV with proper item/line_item grouping
4. **Update tasks** - Modify process_auction_items and generate_receipts
5. **Generate receipts** - One receipt per **line item** (not per item)

### Benefits

- ✅ No data loss - All CSV rows preserved
- ✅ Proper relationships - Items group related line items
- ✅ Correct semantics - Clear distinction between items and line items
- ✅ Future-proof - Can add item-level metadata (notes, categories, etc.)
- ✅ Receipt generation - One receipt per line item as intended

## Expected Outcome

- Items table with ~122 unique items
- LineItems table with 137 line items
- All line items properly associated with their parent item
- Receipts generated for each line item (137 total)
- Change detection working at line item level
- All tests updated and passing
