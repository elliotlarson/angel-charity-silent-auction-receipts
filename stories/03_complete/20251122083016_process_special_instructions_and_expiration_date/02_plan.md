# Implementation Plan: Process Special Instructions and Expiration Date

## Progress Checklist

- [x] Step 1: Add special_instructions and expiration_date fields to AuctionItem struct

## Overview

We need to extend the auction item processing system to add two new fields:

1. **expiration_date** - A string field for expiration information
2. **special_instructions** - A string field for important notes like booking requirements, geographic restrictions, gratuities, etc.

These fields are added to the struct and will default to empty strings. The actual extraction logic will be implemented in a separate story.

## Key Design Decisions

**Field Types:**
- Both fields are strings (not dates or structured data)
- Default to empty strings when not provided
- This keeps the implementation simple and flexible

**Scope:**
- This story only adds the fields to the struct
- Extraction logic will be implemented in a separate story

**Backwards Compatibility:**
- Existing JSON files won't need migration
- New fields are optional additions to the struct

## Implementation Steps

### Step 1: Add special_instructions and expiration_date fields to AuctionItem struct

**Files to modify:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

1. Update the struct definition to include the new fields:

```elixir
defstruct [
  :item_id,
  :short_title,
  :title,
  :description,
  :fair_market_value,
  :categories,
  :special_instructions,
  :expiration_date
]
```

2. Update the type specification:

```elixir
@type t :: %__MODULE__{
  item_id: integer(),
  short_title: String.t(),
  title: String.t(),
  description: String.t(),
  fair_market_value: integer(),
  categories: String.t(),
  special_instructions: String.t(),
  expiration_date: String.t()
}
```

3. Update the `new/1` function to accept and handle the new fields with empty string defaults:

```elixir
def new(attrs) do
  %__MODULE__{
    item_id: parse_integer(attrs[:item_id]),
    short_title: attrs[:short_title] || "",
    title: attrs[:title] || "",
    description: attrs[:description] || "",
    fair_market_value: parse_integer(attrs[:fair_market_value]),
    categories: attrs[:categories] || "",
    special_instructions: attrs[:special_instructions] || "",
    expiration_date: attrs[:expiration_date] || ""
  }
end
```

4. Add tests for the new fields in `test/receipts/auction_item_test.exs`:

```elixir
test "creates auction item with special_instructions and expiration_date" do
  attrs = %{
    item_id: "123",
    short_title: "Test",
    title: "Test Item",
    description: "Test description",
    fair_market_value: "100",
    categories: "TEST",
    special_instructions: "Contact us to book",
    expiration_date: "12/31/2026"
  }

  item = AuctionItem.new(attrs)

  assert item.special_instructions == "Contact us to book"
  assert item.expiration_date == "12/31/2026"
end

test "defaults special_instructions and expiration_date to empty strings" do
  attrs = %{
    item_id: "123",
    short_title: "Test",
    title: "Test Item",
    description: "Test description",
    fair_market_value: "100",
    categories: "TEST"
  }

  item = AuctionItem.new(attrs)

  assert item.special_instructions == ""
  assert item.expiration_date == ""
end
```

**Commit message:** `Add special_instructions and expiration_date fields to AuctionItem struct`

---

## Testing Commands

After implementation, run:
```bash
mix format
mix test
```

## Notes

- Extraction logic for populating these fields from descriptions will be implemented in a future story
- The fields are now part of the struct and JSON output, ready to be populated
- All tests pass successfully
