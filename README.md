# Receipts

Generating silent auction receipts for Angel Charity's 2025 Angel Ball Silent Auction.

## Processing Auction Items

This project includes a Mix task for converting auction item CSV files to JSON format.

### Usage

```bash
mix process_auction_items
```

The task will:
1. Display a list of available CSV files in `db/auction_items/csv/`
2. Prompt you to select a file by number
3. Process the CSV file:
   - Remove empty lines
   - Filter out placeholder rows (items with zero or empty ID or Fair Market Value)
   - Extract relevant fields
4. Save the processed data as JSON in `db/auction_items/json/`

### Extracted Fields

The following fields are extracted from each auction item:

- `item_id` - Item ID
- `short_title` - 15 character description
- `title` - 100 character description
- `description` - 1500 character description
- `fair_market_value` - Fair market value
- `categories` - Item categories

### Example

```bash
$ mix process_auction_items
Available CSV files:
  1. 20251121_auction_items.csv
Select file number: 1
Processing 20251121_auction_items.csv...
Successfully processed 45 items
Output saved to: db/auction_items/json/20251121_auction_items.json
```

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
