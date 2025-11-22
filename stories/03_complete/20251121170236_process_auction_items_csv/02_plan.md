# Implementation Plan: Process Auction Items CSV

## Progress Checklist

- [x] Step 1: Add JSON dependency to mix.exs
- [x] Step 2: Create ProcessAuctionItems mix task with file selection
- [x] Step 3: Add CSV parsing and data cleaning logic
- [x] Step 4: Add field extraction and transformation logic
- [x] Step 5: Add JSON output generation
- [x] Step 6: Add README documentation for the task
- [x] Step 7: Migrate to NimbleCSV for proper quoted field handling
- [x] Step 8: Convert numeric fields to integers using AuctionItem struct

## Overview

This plan implements a Mix task that processes auction item CSV files and converts them to structured JSON. The task will:

1. List available CSV files in `db/auction_items/csv/`
2. Allow interactive file selection
3. Remove empty lines and placeholder rows (zeroed out items)
4. Extract specific fields from the CSV data
5. Transform headers to snake_case format
6. Save processed data as JSON in `db/auction_items/json/`

## Key Design Decisions

**CSV Structure Analysis:**
The sample CSV has:

- Non-data header rows (lines 1-2)
- Column header row at line 3 with actual field names
- Empty line at line 4
- Data rows starting at line 5
- Placeholder rows with `0` values in certain columns (e.g., item 110)

**Field Mapping Strategy:**
We need to extract these specific fields:

- Item ID (column B: "ITEM ID")
- Categories (column M: "CATEGORIES (OPTIONAL)")
- Short Title (column C: "15 CHARACTER DESCRIPTION")
- Title (column E: "100 CHARACTER DESCRIPTION")
- Description (column G: "1500 CHARACTER DESCRIPTION (OPTIONAL)")
- Fair Market Value (column I: "FAIR MARKET VALUE")

**Data Cleaning Rules:**

- Remove rows where ITEM ID is empty or 0
- Remove rows where Fair Market Value is 0 or empty
- Trim all field values
- Handle multi-line descriptions (CSV cells may contain newlines)

**Dependencies:**
Using built-in Elixir libraries only (no external CSV parser) to keep dependencies minimal. We'll use Jason for JSON encoding.

## Implementation Steps

### Step 1: Add JSON dependency to mix.exs

**Files to modify:**

- `mix.exs`

**Changes:**

Add Jason dependency for JSON encoding:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"}
  ]
end
```

**Testing:**
Run `mix deps.get` to fetch the new dependency.

**Commit message:** `Add Jason dependency for JSON encoding`

---

### Step 2: Create ProcessAuctionItems mix task with file selection

**Files to create:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Create the basic Mix task structure with file selection logic:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  @shortdoc "Process auction items CSV files and convert to JSON"

  @csv_dir "db/auction_items/csv"
  @json_dir "db/auction_items/json"

  def run(_args) do
    csv_files = list_csv_files()

    case csv_files do
      [] ->
        Mix.shell().error("No CSV files found in #{@csv_dir}")
      files ->
        selected_file = prompt_file_selection(files)
        process_file(selected_file)
    end
  end

  defp list_csv_files do
    case File.ls(@csv_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".csv"))
        |> Enum.sort()
      {:error, _} ->
        []
    end
  end

  defp prompt_file_selection(files) do
    Mix.shell().info("Available CSV files:")

    files
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      Mix.shell().info("  #{index}. #{file}")
    end)

    selection = Mix.shell().prompt("Select file number:") |> String.trim() |> String.to_integer()
    Enum.at(files, selection - 1)
  end

  defp process_file(filename) do
    Mix.shell().info("Processing #{filename}...")
  end
end
```

Create corresponding test file:

```elixir
defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use ExUnit.Case

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end
end
```

**Testing:**
Run `mix test` to ensure the test passes.

**Commit message:** `Create ProcessAuctionItems mix task with file selection`

---

### Step 3: Add CSV parsing and data cleaning logic

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Add CSV reading and data cleaning functions:

```elixir
defp process_file(filename) do
  csv_path = Path.join(@csv_dir, filename)

  csv_path
  |> read_and_parse_csv()
  |> clean_data()
  |> IO.inspect(label: "Cleaned data")
end

defp read_and_parse_csv(path) do
  path
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == ""))
  |> CSV.decode()
  |> Enum.to_list()
end

defp clean_data(rows) do
  [_title_row, _empty_row, headers | data_rows] = rows

  data_rows
  |> Enum.reject(&is_placeholder_row?/1)
  |> Enum.map(&build_item(&1, headers))
end

defp is_placeholder_row?(row) do
  item_id = get_column(row, 1)
  fair_market_value = get_column(row, 8)

  item_id in ["", "0"] or fair_market_value in ["", "0"]
end

defp get_column(row, index) do
  row
  |> Enum.at(index, "")
  |> to_string()
  |> String.trim()
end
```

Add a simple CSV decoder module since we're not using external dependencies:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems.CSV do
  def decode(stream) do
    stream
    |> Stream.map(&parse_line/1)
  end

  defp parse_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end
end
```

Update tests to verify data cleaning:

```elixir
describe "data cleaning" do
  test "removes placeholder rows with zero item_id" do
    row_with_zero_id = ["", "0", "desc", "", "", "", "", "", "100"]

    assert Mix.Tasks.ProcessAuctionItems.is_placeholder_row?(row_with_zero_id) == true
  end

  test "removes placeholder rows with zero fair_market_value" do
    row_with_zero_fmv = ["", "103", "desc", "", "", "", "", "", "0"]

    assert Mix.Tasks.ProcessAuctionItems.is_placeholder_row?(row_with_zero_fmv) == true
  end

  test "preserves valid auction item rows" do
    valid_row = ["", "103", "desc", "", "title", "", "description", "", "1200"]

    assert Mix.Tasks.ProcessAuctionItems.is_placeholder_row?(valid_row) == false
  end
end
```

Note: These tests require making `is_placeholder_row?/1` public or testing through the public API. Add `@doc false` and make it public for testing:

```elixir
@doc false
def is_placeholder_row?(row) do
  item_id = get_column(row, 1)
  fair_market_value = get_column(row, 8)

  item_id in ["", "0"] or fair_market_value in ["", "0"]
end

@doc false
def get_column(row, index) do
  row
  |> Enum.at(index, "")
  |> to_string()
  |> String.trim()
end
```

**Testing:**
Run `mix test` and manually test with `mix process_auction_items`.

**Commit message:** `Add CSV parsing and data cleaning logic`

---

### Step 4: Add field extraction and transformation logic

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Implement field extraction with header transformation:

```elixir
@field_mappings %{
  "ITEM ID" => :item_id,
  "CATEGORIES (OPTIONAL)" => :categories,
  "15 CHARACTER DESCRIPTION" => :short_title,
  "100 CHARACTER DESCRIPTION" => :title,
  "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
  "FAIR MARKET VALUE" => :fair_market_value
}

defp build_item(row, headers) do
  @field_mappings
  |> Enum.reduce(%{}, fn {header, field_name}, acc ->
    index = find_header_index(headers, header)
    value = get_column(row, index)
    Map.put(acc, field_name, value)
  end)
end

defp find_header_index(headers, target_header) do
  headers
  |> Enum.find_index(fn header ->
    String.upcase(String.trim(header)) == target_header
  end)
end
```

Add tests for field extraction:

```elixir
describe "field extraction" do
  test "extracts all required fields from a row" do
    headers = ["Apply Sales Tax? (Y/N)", "ITEM ID", "15 CHARACTER DESCRIPTION", "",
               "100 CHARACTER DESCRIPTION", "", "1500 CHARACTER DESCRIPTION (OPTIONAL)",
               "", "FAIR MARKET VALUE", "ITEM STARTING BID", "MINIMUM BID INCREMENT",
               "GROUP ID", "CATEGORIES (OPTIONAL)"]

    row = ["", "103", "Landscaping", "11", "One Year Monthly Landscaping Services",
           "37", "Enjoy a beautiful yard", "570", "1200", "480", "100", " 1 ", "HOME"]

    result = Mix.Tasks.ProcessAuctionItems.build_item(row, headers)

    assert Map.keys(result) == [:categories, :description, :fair_market_value,
                                 :item_id, :short_title, :title]
    assert result[:item_id] == "103"
    assert result[:categories] == "HOME"
    assert result[:short_title] == "Landscaping"
    assert result[:title] == "One Year Monthly Landscaping Services"
    assert result[:description] == "Enjoy a beautiful yard"
    assert result[:fair_market_value] == "1200"
  end

  test "transforms header names to snake_case atom keys" do
    headers = ["ITEM ID", "15 CHARACTER DESCRIPTION", "100 CHARACTER DESCRIPTION",
               "1500 CHARACTER DESCRIPTION (OPTIONAL)", "FAIR MARKET VALUE",
               "CATEGORIES (OPTIONAL)"]

    row = ["103", "Short", "Title", "Desc", "100", "CAT"]

    result = Mix.Tasks.ProcessAuctionItems.build_item(row, headers)

    assert is_atom(result[:item_id])
    assert is_atom(result[:short_title])
    assert is_atom(result[:title])
    assert is_atom(result[:description])
    assert is_atom(result[:fair_market_value])
    assert is_atom(result[:categories])
  end

  test "trims whitespace from field values" do
    headers = ["ITEM ID", "CATEGORIES (OPTIONAL)"]
    row = ["  103  ", "  HOME  "]

    result = Mix.Tasks.ProcessAuctionItems.build_item(row, headers)

    assert result[:item_id] == "103"
    assert result[:categories] == "HOME"
  end
end
```

Note: Make `build_item/2` public for testing by adding `@doc false`:

```elixir
@doc false
def build_item(row, headers) do
  @field_mappings
  |> Enum.reduce(%{}, fn {header, field_name}, acc ->
    index = find_header_index(headers, header)
    value = get_column(row, index)
    Map.put(acc, field_name, value)
  end)
end
```

**Testing:**
Run `mix test` and verify field extraction with sample data.

**Commit message:** `Add field extraction and transformation logic`

---

### Step 5: Add JSON output generation

**Files to create:**

- `test/fixtures/auction_items.csv`

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Add JSON encoding and file writing:

```elixir
defp process_file(filename) do
  csv_path = Path.join(@csv_dir, filename)
  json_filename = Path.basename(filename, ".csv") <> ".json"
  json_path = Path.join(@json_dir, json_filename)

  items = csv_path
    |> read_and_parse_csv()
    |> clean_data()

  json_content = Jason.encode!(items, pretty: true)
  File.write!(json_path, json_content)

  Mix.shell().info("Successfully processed #{length(items)} items")
  Mix.shell().info("Output saved to: #{json_path}")
end
```

Create test fixture file `test/fixtures/auction_items.csv`:

```csv
,AUCTION ITEMS,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,
Apply Sales Tax? (Y/N),ITEM ID,15 CHARACTER DESCRIPTION,,100 CHARACTER DESCRIPTION,,1500 CHARACTER DESCRIPTION (OPTIONAL),,FAIR MARKET VALUE,ITEM STARTING BID,MINIMUM BID INCREMENT,GROUP ID,CATEGORIES (OPTIONAL)
,,,,,,,,,,,,,,,
,103,Landscaping,11,One Year Monthly Landscaping Services,37,Enjoy a beautiful yard,570,1200,480,100, 1 ,HOME
,110,not listed ,11,,0,,0,0,0,100, 1 ,,0
,115,Gift Cards,15,$1000 Gift Cards Downtown,74,Downtown Tucson Gift Cards,350,1000,400,100, 1 ,ENTERTAINMENT
```

Add integration tests:

```elixir
describe "full processing pipeline" do
  @fixtures_dir "test/fixtures"
  @output_dir "test/tmp"

  setup do
    File.mkdir_p!(@output_dir)

    on_exit(fn ->
      File.rm_rf!(@output_dir)
    end)

    :ok
  end

  test "processes CSV and creates valid JSON output" do
    csv_path = Path.join(@fixtures_dir, "auction_items.csv")
    json_path = Path.join(@output_dir, "auction_items.json")

    items = csv_path
      |> Mix.Tasks.ProcessAuctionItems.read_and_parse_csv()
      |> Mix.Tasks.ProcessAuctionItems.clean_data()

    json_content = Jason.encode!(items, pretty: true)
    File.write!(json_path, json_content)

    assert File.exists?(json_path)

    {:ok, json_data} = File.read(json_path)
    {:ok, decoded} = Jason.decode(json_data, keys: :atoms)

    assert length(decoded) == 2
    assert Enum.all?(decoded, fn item ->
      Map.has_key?(item, :item_id) and
      Map.has_key?(item, :categories) and
      Map.has_key?(item, :short_title) and
      Map.has_key?(item, :title) and
      Map.has_key?(item, :description) and
      Map.has_key?(item, :fair_market_value)
    end)

    first_item = Enum.at(decoded, 0)
    assert first_item[:item_id] == "103"
    assert first_item[:categories] == "HOME"
    assert first_item[:short_title] == "Landscaping"

    refute Enum.any?(decoded, fn item -> item[:item_id] == "110" end)
  end
end
```

Note: Make `read_and_parse_csv/1` and `clean_data/1` public for testing:

```elixir
@doc false
def read_and_parse_csv(path) do
  path
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == ""))
  |> CSV.decode()
  |> Enum.to_list()
end

@doc false
def clean_data(rows) do
  [_title_row, _empty_row, headers | data_rows] = rows

  data_rows
  |> Enum.reject(&is_placeholder_row?/1)
  |> Enum.map(&build_item(&1, headers))
end
```

**Testing:**
Run `mix test` and manually test with actual CSV file: `mix process_auction_items`.

**Commit message:** `Add JSON output generation`

---

### Step 6: Add README documentation for the task

**Files to modify:**

- `README.md`

**Changes:**

Add a section documenting the ProcessAuctionItems task:

```markdown
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
```

**Testing:**
Verify the documentation is clear and accurate.

**Commit message:** `Add README documentation for auction items task`

---

### Step 7: Migrate to NimbleCSV for proper quoted field handling

**Files to modify:**

- `mix.exs`
- `lib/mix/tasks/process_auction_items/csv.ex`
- `test/fixtures/auction_items.csv`

**Changes:**

**Problem:** The current naive `String.split(",")` CSV parser doesn't handle quoted fields containing commas. When the description field contains text like `"Enjoy a beautiful, worry-free yard..."`, it splits incorrectly, causing:
- Truncated descriptions
- Wrong values in fair_market_value (showing description text instead of dollar amounts)
- Misaligned categories field

Add NimbleCSV dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:nimble_csv, "~> 1.2"}
  ]
end
```

Update `lib/mix/tasks/process_auction_items/csv.ex`:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems.CSV do
  NimbleCSV.define(Parser, separator: ",", escape: "\"")

  def decode(stream) do
    stream
    |> Parser.parse_stream()
  end
end
```

Update `test/fixtures/auction_items.csv` to include quoted fields with commas:

```csv
,AUCTION ITEMS,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,
Apply Sales Tax? (Y/N),ITEM ID,15 CHARACTER DESCRIPTION,,100 CHARACTER DESCRIPTION,,1500 CHARACTER DESCRIPTION (OPTIONAL),,FAIR MARKET VALUE,ITEM STARTING BID,MINIMUM BID INCREMENT,GROUP ID,CATEGORIES (OPTIONAL)
,,,,,,,,,,,,,,,
,103,Landscaping,11,One Year Monthly Landscaping Services,37,"Enjoy a beautiful, worry-free yard all year long.",570,1200,480,100, 1 ,HOME
,110,not listed ,11,,0,,0,0,0,100, 1 ,,0
,115,Gift Cards,15,$1000 Gift Cards Downtown,74,"Downtown Tucson Gift Cards, accepted at more than 50 local businesses.",350,1000,400,100, 1 ,ENTERTAINMENT
```

**Testing:**
Run `mix deps.get` to fetch NimbleCSV, then run `mix test` to ensure all tests pass.
Test manually with the actual CSV file to verify correct parsing.

**Commit message:** `Migrate to NimbleCSV for proper quoted field handling`

---

### Step 8: Convert numeric fields to integers using AuctionItem struct

**Files to create:**

- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

**Problem:** Currently all fields are stored as strings, but `item_id` and `fair_market_value` are numeric fields that should be integers for proper type safety and JSON representation.

**Design Decision:** The `AuctionItem` struct is a domain model and should live in `lib/receipts/` (the main application namespace) rather than in the Mix task directory.

Create `lib/receipts/auction_item.ex`:

```elixir
defmodule Receipts.AuctionItem do
  @enforce_keys [:item_id, :short_title, :title, :description, :fair_market_value, :categories]
  defstruct [:item_id, :short_title, :title, :description, :fair_market_value, :categories]

  @type t :: %__MODULE__{
    item_id: integer(),
    short_title: String.t(),
    title: String.t(),
    description: String.t(),
    fair_market_value: integer(),
    categories: String.t()
  }

  def new(attrs) do
    %__MODULE__{
      item_id: parse_integer(attrs[:item_id]),
      short_title: attrs[:short_title] || "",
      title: attrs[:title] || "",
      description: attrs[:description] || "",
      fair_market_value: parse_integer(attrs[:fair_market_value]),
      categories: attrs[:categories] || ""
    }
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_integer(_), do: 0
end
```

Create `test/receipts/auction_item_test.exs`:

```elixir
defmodule Receipts.AuctionItemTest do
  use ExUnit.Case

  alias Receipts.AuctionItem

  describe "new/1" do
    test "creates struct with integer fields for item_id and fair_market_value" do
      attrs = %{
        item_id: "103",
        short_title: "Landscaping",
        title: "One Year Monthly Landscaping Services",
        description: "Enjoy a beautiful yard",
        fair_market_value: "1200",
        categories: "HOME"
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 103
      assert item.fair_market_value == 1200
      assert item.short_title == "Landscaping"
      assert item.title == "One Year Monthly Landscaping Services"
      assert item.description == "Enjoy a beautiful yard"
      assert item.categories == "HOME"
    end

    test "handles empty strings for numeric fields" do
      attrs = %{
        item_id: "",
        short_title: "Test",
        title: "Test Title",
        description: "Test Desc",
        fair_market_value: "",
        categories: "TEST"
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 0
      assert item.fair_market_value == 0
    end

    test "handles nil values gracefully" do
      attrs = %{
        item_id: "103",
        short_title: nil,
        title: nil,
        description: nil,
        fair_market_value: "1200",
        categories: nil
      }

      item = AuctionItem.new(attrs)

      assert item.item_id == 103
      assert item.fair_market_value == 1200
      assert item.short_title == ""
      assert item.title == ""
      assert item.description == ""
      assert item.categories == ""
    end
  end
end
```

Update `lib/mix/tasks/process_auction_items.ex`:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.AuctionItem

  # ... existing code ...

  @doc false
  def build_item(row, headers) do
    attrs = @field_mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        case find_header_index(headers, header) do
          nil -> Map.put(acc, field_name, "")
          index -> Map.put(acc, field_name, get_column(row, index))
        end
      end)

    AuctionItem.new(attrs)
  end

  # ... rest of the code ...
end
```

Update tests in `test/mix/tasks/process_auction_items_test.exs`:

```elixir
describe "build_item/2" do
  test "extracts all required fields from a row and converts numeric fields to integers" do
    headers = ["Apply Sales Tax? (Y/N)", "ITEM ID", "15 CHARACTER DESCRIPTION", "",
               "100 CHARACTER DESCRIPTION", "", "1500 CHARACTER DESCRIPTION (OPTIONAL)",
               "", "FAIR MARKET VALUE", "ITEM STARTING BID", "MINIMUM BID INCREMENT",
               "GROUP ID", "CATEGORIES (OPTIONAL)"]

    row = ["", "103", "Landscaping", "11", "One Year Monthly Landscaping Services",
           "37", "Enjoy a beautiful yard", "570", "1200", "480", "100", " 1 ", "HOME"]

    result = ProcessAuctionItems.build_item(row, headers)

    assert result.item_id == 103
    assert result.categories == "HOME"
    assert result.short_title == "Landscaping"
    assert result.title == "One Year Monthly Landscaping Services"
    assert result.description == "Enjoy a beautiful yard"
    assert result.fair_market_value == 1200
  end

  test "returns AuctionItem struct with typed fields" do
    headers = ["ITEM ID", "15 CHARACTER DESCRIPTION", "100 CHARACTER DESCRIPTION",
               "1500 CHARACTER DESCRIPTION (OPTIONAL)", "FAIR MARKET VALUE",
               "CATEGORIES (OPTIONAL)"]

    row = ["103", "Short", "Title", "Desc", "100", "CAT"]

    result = ProcessAuctionItems.build_item(row, headers)

    assert is_struct(result, Receipts.AuctionItem)
    assert is_integer(result.item_id)
    assert is_integer(result.fair_market_value)
    assert is_binary(result.short_title)
    assert is_binary(result.title)
    assert is_binary(result.description)
    assert is_binary(result.categories)
  end

  test "trims whitespace from field values" do
    headers = ["ITEM ID", "CATEGORIES (OPTIONAL)"]
    row = ["  103  ", "  HOME  "]

    result = ProcessAuctionItems.build_item(row, headers)

    assert result.item_id == 103
    assert result.categories == "HOME"
  end
end

describe "full processing pipeline" do
  test "processes CSV and creates valid JSON output" do
    csv_path = Path.join(@fixtures_dir, "auction_items.csv")
    json_path = Path.join(@output_dir, "auction_items.json")

    items = csv_path
      |> ProcessAuctionItems.read_and_parse_csv()
      |> ProcessAuctionItems.clean_data()

    json_content = Jason.encode!(items, pretty: true)
    File.write!(json_path, json_content)

    assert File.exists?(json_path)

    {:ok, json_data} = File.read(json_path)
    {:ok, decoded} = Jason.decode(json_data, keys: :atoms)

    assert length(decoded) == 2
    assert Enum.all?(decoded, fn item ->
      Map.has_key?(item, :item_id) and
      Map.has_key?(item, :categories) and
      Map.has_key?(item, :short_title) and
      Map.has_key?(item, :title) and
      Map.has_key?(item, :description) and
      Map.has_key?(item, :fair_market_value)
    end)

    first_item = Enum.at(decoded, 0)
    assert first_item[:item_id] == 103  # Now an integer
    assert first_item[:categories] == "HOME"
    assert first_item[:short_title] == "Landscaping"
    assert first_item[:fair_market_value] == 1200  # Now an integer

    refute Enum.any?(decoded, fn item -> item[:item_id] == 110 end)
  end
end
```

**Testing:**
Run `mix test` to ensure all tests pass with the new struct-based approach.

**Commit message:** `Convert numeric fields to integers using AuctionItem struct`

---

## Session Continuity Notes

Each step builds upon the previous one. When resuming:

1. Check the progress checklist to see which steps are complete
2. Read the relevant code files to understand current state
3. Continue with the next unchecked step
4. Update the checklist after each commit

The implementation follows a clear progression:

- Step 1: Dependencies
- Step 2: Task scaffold + file selection
- Step 3: CSV parsing + cleaning
- Step 4: Field extraction + transformation
- Step 5: JSON output
- Step 6: README documentation
- Step 7: NimbleCSV migration (fixes quoted field parsing)
- Step 8: Item struct with integer fields (type safety)

Each step leaves the codebase in a working state with passing tests.
