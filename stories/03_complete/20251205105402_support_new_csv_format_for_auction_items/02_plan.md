# Implementation Plan: Support new CSV format for auction items

## Progress Checklist

- [x] Step 1: Add CSV format detection and dual format support
- [x] Step 2: Update placeholder row detection for new format
- [x] Step 3: Restore data from old CSV file
- [x] Step 4: Update schema: remove short_title, add value and slug fields
- [x] Step 5: Simplify to new CSV format only

## Overview

**Initial Implementation (Steps 1-3):**
The auction items CSV source changed to a new format. We initially implemented dual format support to handle both old and new CSV formats.

**Updated Approach (Steps 4-5):**
After reviewing the new format, we discovered it has the data already structured in separate columns (Restrictions, Dates/Expiration), eliminating the need for AI processing. We will:

1. Update schema to remove short_title, rename fair_market_value to value, add slug field
2. Remove all old format support and dual-format complexity
3. Use Qtego # as identifier (already numeric)
4. Map Restrictions → notes and Dates/Expiration → expiration_notice directly
5. Remove AI processing entirely (data already structured)

---

### Step 4: Update schema: remove short_title, add value and slug fields

**Files to modify:**
- `priv/repo/migrations/20251124155250_create_line_items.exs`
- `lib/receipts/line_item.ex`
- `test/receipts/line_item_test.exs`

**Changes:**

1. **Delete existing database files:**
```bash
rm db/receipts_dev.db*
rm db/receipts_test.db*
```

2. **Update `priv/repo/migrations/20251124155250_create_line_items.exs`:**

Remove short_title and item_identifier fields, rename fair_market_value to value, add slug field:

```elixir
defmodule Receipts.Repo.Migrations.CreateLineItems do
  use Ecto.Migration

  def change do
    create table(:line_items) do
      add :item_id, references(:items, on_delete: :delete_all), null: false
      add :identifier, :integer, null: false, default: 0
      add :title, :text, null: false, default: ""
      add :slug, :string, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:line_items, [:item_id])
    create index(:line_items, [:csv_row_hash])
    create unique_index(:line_items, [:item_id, :identifier])
  end
end
```

3. **Update `lib/receipts/line_item.ex` schema:**

```elixir
schema "line_items" do
  field(:identifier, :integer)
  field(:title, :string)
  field(:slug, :string)
  field(:description, :string)
  field(:value, :integer)
  field(:categories, :string)
  field(:notes, :string)
  field(:expiration_notice, :string)
  field(:csv_row_hash, :string)
  field(:csv_raw_line, :string)

  belongs_to(:item, Receipts.Item)

  timestamps(type: :utc_datetime)
end
```

4. **Update changeset in `lib/receipts/line_item.ex`:**

```elixir
def changeset(%__MODULE__{} = line_item \\ %__MODULE__{}, attrs) do
  line_item
  |> cast(attrs, [
    :item_id,
    :identifier,
    :title,
    :description,
    :value,
    :categories,
    :notes,
    :expiration_notice,
    :csv_row_hash,
    :csv_raw_line
  ])
  |> apply_defaults()
  |> generate_slug()
  |> validate_required([:item_id, :identifier, :slug, :csv_row_hash, :csv_raw_line])
  |> ensure_non_negative_integers()
  |> normalize_text_fields()
  |> foreign_key_constraint(:item_id)
  |> unique_constraint([:item_id, :identifier])
end

defp generate_slug(changeset) do
  case get_change(changeset, :title) do
    nil ->
      changeset

    title ->
      slug =
        title
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s]/, "")
        |> String.replace(~r/\s+/, "_")
        |> String.trim("_")

      put_change(changeset, :slug, slug)
  end
end

defp apply_defaults(changeset) do
  changeset
  |> put_default_if_nil_or_empty(:value, 0)
  |> put_default_if_nil(:title, "")
  |> put_default_if_nil(:description, "")
  |> put_default_if_nil(:categories, "")
  |> put_default_if_nil(:notes, "")
  |> put_default_if_nil(:expiration_notice, "")
end

defp ensure_non_negative_integers(changeset) do
  changeset
  |> update_change(:value, &max(&1 || 0, 0))
end

defp normalize_text_fields(changeset) do
  changeset
  |> update_change(:title, &TextNormalizer.normalize/1)
  |> update_change(:description, &normalize_and_format_description/1)
end
```

5. **Update `receipt_filename` function in `lib/receipts/line_item.ex`:**

```elixir
def receipt_filename(line_item) do
  alias Receipts.Repo

  line_item = Repo.preload(line_item, :item)
  total = count_for_item(line_item.item_id)

  if total > 1 do
    "receipt_#{line_item.item.item_identifier}_#{line_item.identifier}_of_#{total}_#{line_item.slug}"
  else
    "receipt_#{line_item.item.item_identifier}_#{line_item.slug}"
  end
end
```

6. **Update tests in `test/receipts/line_item_test.exs`:**

Replace all references to `:fair_market_value` with `:value`:

```elixir
# Update test fixtures
@valid_attrs %{
  item_id: 1,
  identifier: 1,
  title: "Test Item",
  description: "Test description",
  value: 100,
  csv_row_hash: "abc123",
  csv_raw_line: "test,data"
}

# Add test for slug generation
describe "slug generation" do
  test "generates slug from title" do
    attrs = Map.put(@valid_attrs, :title, "Landscaping Services")
    changeset = LineItem.changeset(%LineItem{}, attrs)
    assert changeset.changes.slug == "landscaping_services"
  end

  test "removes special characters from slug" do
    attrs = Map.put(@valid_attrs, :title, "Art & Wine Tasting!")
    changeset = LineItem.changeset(%LineItem{}, attrs)
    assert changeset.changes.slug == "art_wine_tasting"
  end

  test "collapses multiple spaces in slug" do
    attrs = Map.put(@valid_attrs, :title, "Premium   Spa   Package")
    changeset = LineItem.changeset(%LineItem{}, attrs)
    assert changeset.changes.slug == "premium_spa_package"
  end

  test "handles empty title" do
    attrs = Map.put(@valid_attrs, :title, "")
    changeset = LineItem.changeset(%LineItem{}, attrs)
    assert changeset.changes.slug == ""
  end
end

# Update receipt_filename tests to use slug
describe "receipt_filename/1" do
  test "generates filename with slug for single item" do
    line_item = %LineItem{
      slug: "landscaping_services",
      item: %Item{item_identifier: 103},
      item_id: 1,
      identifier: 1
    }
    
    assert LineItem.receipt_filename(line_item) == "receipt_103_landscaping_services"
  end
end

# Remove any tests that reference short_title field
```

7. **Recreate databases:**
```bash
mix ecto.create
mix ecto.migrate
```

**Testing:**
```bash
mix test test/receipts/line_item_test.exs
```

All tests should pass with new schema.

**Commit message:** `Update schema: remove short_title, add value and slug fields`

---

### Step 5: Simplify to new CSV format only

**Files to modify:**
- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Remove all old format support code and update to use new CSV format exclusively with Qtego #, Restrictions, and Dates/Expiration columns.

1. **Remove format detection functions from `lib/mix/tasks/process_auction_items.ex`:**

Delete these functions entirely:
- `detect_format/1`
- `detect_format_and_structure/1`
- `field_mappings(:old_format)` 
- `extract_numeric_identifier/1`
- `parse_currency/1` (will be replaced with parse_value)

2. **Simplify `field_mappings` to single new format:**

```elixir
defp field_mappings do
  %{
    "QTEGO #" => :item_identifier,
    "CATEGORY" => :categories,
    "ITEM DONATED TITLE" => :title,
    "DETAILED ITEM DESCRIPTION" => :description,
    "VALUE" => :value,
    "RESTRICTIONS" => :notes,
    "DATES/ EXPIRATION" => :expiration_notice
  }
end
```

3. **Simplify `process_rows/2`:**

```elixir
defp process_rows(rows, _opts) do
  [_title_row, headers | data_rows] = rows

  valid_rows = Enum.reject(data_rows, &is_placeholder_row?(&1, headers))
  total = length(valid_rows)

  stats = %{
    new_items: 0,
    new_line_items: 0,
    updated: 0,
    skipped: 0,
    deleted: 0,
    deleted_items: 0
  }

  rows_by_item = group_rows_by_item(valid_rows, headers)

  {stats, processed_line_item_ids} =
    valid_rows
    |> Enum.with_index(1)
    |> Enum.reduce({stats, MapSet.new()}, fn {row, csv_index}, {acc, seen} ->
      item_identifier_str = get_item_identifier(row, headers)
      item_identifier = String.to_integer(item_identifier_str)
      position = get_position_within_item(row, rows_by_item[item_identifier])

      {updated_stats, line_item_id} =
        process_row(row, headers, csv_index, total, position, acc)

      {updated_stats, MapSet.put(seen, line_item_id)}
    end)

  stats = delete_removed_line_items(processed_line_item_ids, stats)
  stats = delete_empty_items(stats)

  Mix.shell().info("\nSummary:")
  Mix.shell().info("  New items: #{stats.new_items}")
  Mix.shell().info("  New line items: #{stats.new_line_items}")
  Mix.shell().info("  Updated line items: #{stats.updated}")
  Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")
  Mix.shell().info("  Deleted items: #{stats.deleted_items}")
  Mix.shell().info("  Deleted line items: #{stats.deleted}")

  stats
end
```

4. **Simplify `get_item_identifier/2`:**

```elixir
defp get_item_identifier(row, headers) do
  get_column(row, find_header_index(headers, "QTEGO #"))
end
```

5. **Simplify `group_rows_by_item/2`:**

```elixir
defp group_rows_by_item(rows, headers) do
  rows
  |> Enum.group_by(fn row ->
    item_identifier_str = get_item_identifier(row, headers)
    String.to_integer(item_identifier_str)
  end)
end
```

6. **Update `is_placeholder_row?/2`:**

```elixir
@doc false
def is_placeholder_row?(row, headers) do
  item_id = get_item_identifier(row, headers)
  value = get_column(row, find_header_index(headers, "VALUE"))

  item_id in ["", "0"] or value in ["", "0", "$0", "$0.00"]
end
```

7. **Simplify `process_row/6`:**

```elixir
defp process_row(row, headers, csv_index, total, identifier, stats) do
  csv_raw_line = Enum.join(row, ",")
  csv_row_hash = hash_csv_row(csv_raw_line)

  item_identifier_str = get_item_identifier(row, headers)
  item_identifier = String.to_integer(item_identifier_str)

  {item, item_created} = find_or_create_item(item_identifier)
  stats = if item_created, do: %{stats | new_items: stats.new_items + 1}, else: stats

  existing_by_position =
    Repo.one(
      from(li in LineItem,
        where: li.item_id == ^item.id and li.identifier == ^identifier
      )
    )

  {stats, line_item_id} =
    cond do
      not is_nil(existing_by_position) and existing_by_position.csv_row_hash == csv_row_hash ->
        Mix.shell().info(
          "[#{csv_index}/#{total}] Skipped line item for ##{item_identifier} (unchanged)"
        )

        {%{stats | skipped: stats.skipped + 1}, existing_by_position.id}

      not is_nil(existing_by_position) ->
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id)
        changeset = LineItem.changeset(existing_by_position, attrs)
        {:ok, updated_item} = Repo.update(changeset)
        Mix.shell().info("[#{csv_index}/#{total}] Updated line item for ##{item_identifier}")
        {%{stats | updated: stats.updated + 1}, updated_item.id}

      true ->
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id)
        attrs_with_identifier = Map.put(attrs, :identifier, identifier)
        changeset = LineItem.changeset(%LineItem{}, attrs_with_identifier)
        {:ok, new_item} = Repo.insert(changeset)
        Mix.shell().info("[#{csv_index}/#{total}] Created line item for ##{item_identifier}")
        {%{stats | new_line_items: stats.new_line_items + 1}, new_item.id}
    end

  {stats, line_item_id}
end
```

8. **Simplify `build_attrs/5`:**

```elixir
defp build_attrs(row, headers, csv_row_hash, csv_raw_line, item_id) do
  mappings = field_mappings()

  attrs =
    mappings
    |> Enum.reduce(%{}, fn {header, field_name}, acc ->
      if field_name == :item_identifier do
        acc
      else
        value =
          case find_header_index(headers, header) do
            nil -> ""
            index -> get_column(row, index)
          end

        normalized_value =
          case {field_name, value} do
            {:value, ""} -> nil
            {:value, val} -> parse_value(val)
            _ -> value
          end

        Map.put(acc, field_name, normalized_value)
      end
    end)

  attrs
  |> Map.put(:item_id, item_id)
  |> Map.put(:csv_row_hash, csv_row_hash)
  |> Map.put(:csv_raw_line, csv_raw_line)
end

@doc false
def parse_value(value) do
  value
  |> String.replace(~r/[$,\s]/, "")
  |> String.split(".")
  |> List.first()
  |> case do
    "" -> ""
    num -> num
  end
end
```

9. **Remove OptionParser skip_ai_processing option:**

```elixir
{opts, positional_args, _} =
  OptionParser.parse(args, switches: [], aliases: [])
```

10. **Update tests in `test/mix/tasks/process_auction_items_test.exs`:**

Remove all old format tests and update for new format only:

```elixir
defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use Receipts.DataCase

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(ProcessAuctionItems)
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end

  describe "is_placeholder_row?/2" do
    test "returns true when qtego number is zero" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Value"]
      row_with_zero_id = ["6/5/2025", "0", "Some Item", "$100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id, headers) == true
    end

    test "returns true when value is zero" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Value"]
      row_with_zero_value = ["6/5/2025", "103", "Some Item", "$0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_value, headers) == true
    end

    test "returns false for valid auction item row" do
      headers = ["Date", "Qtego #", "Item Donated Title", "Value"]
      valid_row = ["6/5/2025", "103", "Landscaping Services", "$1,200.00"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row, headers) == false
    end
  end

  describe "parse_value/1" do
    test "removes dollar signs and commas" do
      assert ProcessAuctionItems.parse_value("$1,200.00") == "1200"
      assert ProcessAuctionItems.parse_value("$2,400.00") == "2400"
      assert ProcessAuctionItems.parse_value("$500.00") == "500"
    end

    test "handles values without formatting" do
      assert ProcessAuctionItems.parse_value("1200") == "1200"
      assert ProcessAuctionItems.parse_value("500") == "500"
    end

    test "handles empty values" do
      assert ProcessAuctionItems.parse_value("") == ""
      assert ProcessAuctionItems.parse_value("$0") == "0"
    end
  end
end
```

**Testing:**
```bash
mix test test/mix/tasks/process_auction_items_test.exs
mix test
```

All tests should pass.

**Commit message:** `Simplify to new CSV format only`
