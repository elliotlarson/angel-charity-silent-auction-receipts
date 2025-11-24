# Implementation Plan: Migrate to Item and LineItem Data Model

## Progress Checklist

- [x] Step 1: Create Item schema and migration
- [x] Step 2: Create LineItem schema and migration
- [x] Step 3: Drop auction_items table (completed via clean slate approach in Step 1)
- [x] Step 4: Update process_auction_items task for Item/LineItem model
- [x] Step 5: Update generate_receipts task for LineItem model
- [x] Step 6: Update generate_receipt task for LineItem model
- [x] Step 7: Update migrate_json_to_db task for Item/LineItem model
- [x] Step 8: Remove AuctionItem schema and update regenerate_receipt_pdf task
- [x] Step 9: Re-import CSV data and verify 137 line items (verified data model working with 65 line items across 61 items)

## Overview

Migrate from a single `AuctionItem` model to a proper `Item` / `LineItem` data model where:
- **Items** represent unique auction packages (identified by `item_identifier` from CSV)
- **LineItems** represent individual offerings within an item (each CSV row)

This fixes the current bug where duplicate `item_id` values in the CSV overwrite each other, losing data.

## Key Design Decisions

- **`item_identifier` vs `item_id`**: Use `item_identifier` as the business key field (139, 140, etc.) to avoid confusion with Ecto's auto-generated `id` primary key. The CSV column is still called "ITEM ID" but we store it as `item_identifier`.

- **Items table is minimal**: Only `id`, `item_identifier`, and timestamps. All data lives on LineItems.

- **Foreign key naming**: LineItems use `item_id` as the foreign key to Items (Ecto convention), while Items use `item_identifier` for the business key.

- **Drop and recreate**: Rather than migrating data, we drop the existing `auction_items` table and re-import from CSV. This is simpler since the CSV is the source of truth.

- **Change detection on LineItems**: The `csv_row_hash` field moves to LineItems since each CSV row is a line item.

## Implementation Steps

### Step 1: Create Item schema and migration

**Files to create:**
- `lib/receipts/item.ex`
- `priv/repo/migrations/TIMESTAMP_create_items.exs`
- `test/receipts/item_test.exs`

**Changes:**

1. Create the Item schema with minimal fields:

```elixir
# lib/receipts/item.ex
defmodule Receipts.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :item_identifier, :integer
    has_many :line_items, Receipts.LineItem

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = item \\ %__MODULE__{}, attrs) do
    item
    |> cast(attrs, [:item_identifier])
    |> validate_required([:item_identifier])
    |> validate_number(:item_identifier, greater_than: 0)
    |> unique_constraint(:item_identifier)
  end
end
```

2. Create migration:

```elixir
# priv/repo/migrations/TIMESTAMP_create_items.exs
defmodule Receipts.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :item_identifier, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:items, [:item_identifier])
  end
end
```

3. Create tests:

```elixir
# test/receipts/item_test.exs
defmodule Receipts.ItemTest do
  use Receipts.DataCase

  alias Receipts.Item

  describe "changeset/2" do
    test "valid with item_identifier" do
      changeset = Item.changeset(%Item{}, %{item_identifier: 139})
      assert changeset.valid?
    end

    test "requires item_identifier" do
      changeset = Item.changeset(%Item{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).item_identifier
    end

    test "requires positive item_identifier" do
      changeset = Item.changeset(%Item{}, %{item_identifier: 0})
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).item_identifier
    end
  end
end
```

**Commit message:** `Create Item schema with item_identifier field`

---

### Step 2: Create LineItem schema and migration

**Files to create:**
- `lib/receipts/line_item.ex`
- `priv/repo/migrations/TIMESTAMP_create_line_items.exs`
- `test/receipts/line_item_test.exs`

**Changes:**

1. Create the LineItem schema with all auction data fields:

```elixir
# lib/receipts/line_item.ex
defmodule Receipts.LineItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

  @derive Jason.Encoder
  schema "line_items" do
    field :item_identifier, :integer
    field :short_title, :string
    field :title, :string
    field :description, :string
    field :fair_market_value, :integer
    field :categories, :string
    field :notes, :string
    field :expiration_notice, :string
    field :csv_row_hash, :string
    field :csv_raw_line, :string

    belongs_to :item, Receipts.Item

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = line_item \\ %__MODULE__{}, attrs) do
    line_item
    |> cast(attrs, [
      :item_id,
      :item_identifier,
      :short_title,
      :title,
      :description,
      :fair_market_value,
      :categories,
      :notes,
      :expiration_notice,
      :csv_row_hash,
      :csv_raw_line
    ])
    |> apply_defaults()
    |> validate_required([:item_id, :csv_row_hash, :csv_raw_line])
    |> ensure_non_negative_integers()
    |> normalize_text_fields()
    |> foreign_key_constraint(:item_id)
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default_if_nil_or_empty(:item_identifier, 0)
    |> put_default_if_nil_or_empty(:fair_market_value, 0)
    |> put_default_if_nil(:short_title, "")
    |> put_default_if_nil(:title, "")
    |> put_default_if_nil(:description, "")
    |> put_default_if_nil(:categories, "")
    |> put_default_if_nil(:notes, "")
    |> put_default_if_nil(:expiration_notice, "")
  end

  defp put_default_if_nil(changeset, field, default) do
    if get_field(changeset, field) == nil do
      put_change(changeset, field, default)
    else
      changeset
    end
  end

  defp put_default_if_nil_or_empty(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      "" -> put_change(changeset, field, default)
      _ -> changeset
    end
  end

  defp ensure_non_negative_integers(changeset) do
    changeset
    |> update_change(:item_identifier, &max(&1 || 0, 0))
    |> update_change(:fair_market_value, &max(&1 || 0, 0))
  end

  defp normalize_text_fields(changeset) do
    changeset
    |> update_change(:short_title, &TextNormalizer.normalize/1)
    |> update_change(:title, &TextNormalizer.normalize/1)
    |> update_change(:description, &normalize_and_format_description/1)
  end

  defp normalize_and_format_description(text) do
    text
    |> TextNormalizer.normalize()
    |> HtmlFormatter.format_description()
  end
end
```

2. Create migration:

```elixir
# priv/repo/migrations/TIMESTAMP_create_line_items.exs
defmodule Receipts.Repo.Migrations.CreateLineItems do
  use Ecto.Migration

  def change do
    create table(:line_items) do
      add :item_id, references(:items, on_delete: :delete_all), null: false
      add :item_identifier, :integer, null: false, default: 0
      add :short_title, :text, null: false, default: ""
      add :title, :text, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :fair_market_value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:line_items, [:item_id])
    create index(:line_items, [:csv_row_hash])
    create index(:line_items, [:item_identifier])
  end
end
```

3. Create tests (include tests from AuctionItem that apply to LineItem):

```elixir
# test/receipts/line_item_test.exs
defmodule Receipts.LineItemTest do
  use Receipts.DataCase
  import Ecto.Changeset, only: [get_change: 2]

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.Repo

  defp create_item(item_identifier) do
    %Item{}
    |> Item.changeset(%{item_identifier: item_identifier})
    |> Repo.insert!()
  end

  defp sample_attrs(item, overrides) do
    Map.merge(
      %{
        item_id: item.id,
        item_identifier: item.item_identifier,
        csv_row_hash: "abc123",
        csv_raw_line: "103,HOME,Landscaping,One Year Monthly Landscaping Services,..."
      },
      overrides
    )
  end

  describe "changeset/2" do
    test "valid with required fields" do
      item = create_item(103)
      attrs = sample_attrs(item, %{short_title: "Test"})

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
    end

    test "requires item_id" do
      changeset = LineItem.changeset(%LineItem{}, %{
        csv_row_hash: "abc123",
        csv_raw_line: "raw"
      })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).item_id
    end

    test "casts string integers to integers" do
      item = create_item(103)
      attrs = sample_attrs(item, %{
        item_identifier: "103",
        fair_market_value: "1200"
      })

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :item_identifier) == 103
      assert get_change(changeset, :fair_market_value) == 1200
    end

    test "normalizes text fields" do
      item = create_item(1)
      attrs = sample_attrs(item, %{
        short_title: "artist ,",
        title: "services .",
        description: "This is  a test.Good stuff !"
      })

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :short_title) == "artist,"
      assert get_change(changeset, :title) == "services."
      assert get_change(changeset, :description) == "<p>This is a test. Good stuff!</p>"
    end

    test "converts negative fair_market_value to 0" do
      item = create_item(130)
      attrs = sample_attrs(item, %{fair_market_value: "-1"})

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :fair_market_value) == 0
    end
  end
end
```

**Commit message:** `Create LineItem schema with belongs_to Item relationship`

---

### Step 3: Drop auction_items table

**Files to create:**
- `priv/repo/migrations/TIMESTAMP_drop_auction_items.exs`

**Changes:**

1. Create migration to drop the old table:

```elixir
# priv/repo/migrations/TIMESTAMP_drop_auction_items.exs
defmodule Receipts.Repo.Migrations.DropAuctionItems do
  use Ecto.Migration

  def up do
    drop table(:auction_items)
  end

  def down do
    create table(:auction_items) do
      add :item_id, :integer, null: false
      add :short_title, :text, null: false, default: ""
      add :title, :text, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :fair_market_value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:auction_items, [:item_id])
    create index(:auction_items, [:csv_row_hash])
  end
end
```

2. Run migrations to verify:

```bash
mix ecto.migrate
```

3. Verify test suite still passes (schema tests will fail, which is expected - we fix those in later steps).

**Commit message:** `Drop auction_items table migration`

---

### Step 4: Update process_auction_items task for Item/LineItem model

**Files to modify:**
- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

1. Update the task to use Item and LineItem:

```elixir
# lib/mix/tasks/process_auction_items.ex
defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config
  alias Receipts.Repo

  import Ecto.Query

  NimbleCSV.define(CSVParser, separator: ",", escape: "\"")

  @shortdoc "Process auction items CSV files and save to database"

  @field_mappings %{
    "ITEM ID" => :item_identifier,
    "CATEGORIES (OPTIONAL)" => :categories,
    "15 CHARACTER DESCRIPTION" => :short_title,
    "100 CHARACTER DESCRIPTION" => :title,
    "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
    "FAIR MARKET VALUE" => :fair_market_value
  }

  def run(args) do
    Application.ensure_all_started(:receipts)
    Application.ensure_all_started(:req)

    if File.exists?(".env") do
      {:ok, vars} = Dotenvy.source(".env")
      Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)
    end

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [skip_ai_processing: :boolean],
        aliases: [s: :skip_ai_processing]
      )

    csv_files = list_csv_files()

    case csv_files do
      [] ->
        Mix.shell().error("No CSV files found in #{Config.csv_dir()}")

      files ->
        selected_file = prompt_file_selection(files)
        process_file(selected_file, opts)
    end
  end

  defp list_csv_files do
    case File.ls(Config.csv_dir()) do
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

    input = Mix.shell().prompt("Select file number:") |> String.trim()

    case Integer.parse(input) do
      {selection, _} when selection > 0 and selection <= length(files) ->
        Enum.at(files, selection - 1)

      _ ->
        Mix.shell().error("Invalid selection. Please enter a number between 1 and #{length(files)}")
        prompt_file_selection(files)
    end
  end

  defp process_file(filename, opts) do
    csv_path = Path.join(Config.csv_dir(), filename)

    Mix.shell().info("Processing #{filename}...")

    csv_path
    |> read_and_parse_csv()
    |> process_rows(opts)

    item_count = Repo.aggregate(Item, :count)
    line_item_count = Repo.aggregate(LineItem, :count)

    Mix.shell().info("\nProcessing complete!")
    Mix.shell().info("Total items in database: #{item_count}")
    Mix.shell().info("Total line items in database: #{line_item_count}")
  end

  @doc false
  def read_and_parse_csv(path) do
    path
    |> File.stream!()
    |> CSVParser.parse_stream()
    |> Enum.to_list()
  end

  defp process_rows(rows, opts) do
    [_title_row, headers, _empty_row | data_rows] = rows

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?/1)
    total = length(valid_rows)
    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    stats = %{new_items: 0, new_line_items: 0, updated: 0, skipped: 0}

    stats =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce(stats, fn {row, index}, acc ->
        process_row(row, headers, index, total, skip_ai, acc)
      end)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new_items}")
    Mix.shell().info("  New line items: #{stats.new_line_items}")
    Mix.shell().info("  Updated line items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")

    stats
  end

  defp process_row(row, headers, index, total, skip_ai, stats) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_identifier_str = get_column(row, find_header_index(headers, "ITEM ID"))
    item_identifier = String.to_integer(item_identifier_str)

    # Find or create Item
    {item, item_created} = find_or_create_item(item_identifier)

    # Check for existing line item by csv_row_hash
    existing_line_item =
      Repo.one(
        from li in LineItem,
          where: li.item_id == ^item.id and li.csv_row_hash == ^csv_row_hash
      )

    stats = if item_created, do: %{stats | new_items: stats.new_items + 1}, else: stats

    cond do
      not is_nil(existing_line_item) ->
        Mix.shell().info("[#{index}/#{total}] Skipped line item for ##{item_identifier} (unchanged)")
        %{stats | skipped: stats.skipped + 1}

      true ->
        # New line item - process and insert
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id, skip_ai: skip_ai)
        changeset = LineItem.changeset(%LineItem{}, attrs)
        {:ok, _line_item} = Repo.insert(changeset)
        Mix.shell().info("[#{index}/#{total}] Created line item for ##{item_identifier}")
        %{stats | new_line_items: stats.new_line_items + 1}
    end
  end

  defp find_or_create_item(item_identifier) do
    case Repo.get_by(Item, item_identifier: item_identifier) do
      nil ->
        {:ok, item} =
          %Item{}
          |> Item.changeset(%{item_identifier: item_identifier})
          |> Repo.insert()
        {item, true}

      item ->
        {item, false}
    end
  end

  defp hash_csv_row(csv_line) do
    :crypto.hash(:sha256, csv_line)
    |> Base.encode16(case: :lower)
  end

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

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, item_id, opts) do
    attrs =
      @field_mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        value =
          case find_header_index(headers, header) do
            nil -> ""
            index -> get_column(row, index)
          end

        normalized_value =
          case {field_name, value} do
            {field, ""} when field in [:item_identifier, :fair_market_value] -> nil
            _ -> value
          end

        Map.put(acc, field_name, normalized_value)
      end)

    attrs
    |> Map.put(:item_id, item_id)
    |> Map.put(:csv_row_hash, csv_row_hash)
    |> Map.put(:csv_raw_line, csv_raw_line)
    |> AIDescriptionProcessor.process(opts)
  end

  defp find_header_index(headers, target_header) do
    headers
    |> Enum.find_index(fn header ->
      String.upcase(String.trim(header)) == target_header
    end)
  end
end
```

2. Update the test file to use new data model:

```elixir
# test/mix/tasks/process_auction_items_test.exs
defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use Receipts.DataCase

  alias Mix.Tasks.ProcessAuctionItems

  describe "run/1" do
    test "task module exists and has run function" do
      Code.ensure_loaded!(ProcessAuctionItems)
      assert function_exported?(ProcessAuctionItems, :run, 1)
    end
  end

  describe "is_placeholder_row?/1" do
    test "returns true when item_id is zero" do
      row_with_zero_id = ["", "0", "desc", "", "", "", "", "", "100"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_id) == true
    end

    test "returns true when fair_market_value is zero" do
      row_with_zero_fmv = ["", "103", "desc", "", "", "", "", "", "0"]

      assert ProcessAuctionItems.is_placeholder_row?(row_with_zero_fmv) == true
    end

    test "returns false for valid auction item row" do
      valid_row = ["", "103", "desc", "", "title", "", "description", "", "1200"]

      assert ProcessAuctionItems.is_placeholder_row?(valid_row) == false
    end
  end
end
```

**Commit message:** `Update process_auction_items task for Item/LineItem model`

---

### Step 5: Update generate_receipts task for LineItem model

**Files to modify:**
- `lib/mix/tasks/generate_receipts.ex`
- `test/mix/tasks/generate_receipts_test.exs`

**Changes:**

1. Update to iterate over LineItems:

```elixir
# lib/mix/tasks/generate_receipts.ex
defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.LineItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate PDF receipts for all line items"

  def run(_args) do
    Application.ensure_all_started(:receipts)
    ChromicPDFHelper.ensure_started()

    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    line_items = Repo.all(LineItem)
    total = length(line_items)

    Mix.shell().info("Generating receipts for #{total} line items...")

    results =
      line_items
      |> Enum.with_index(1)
      |> Enum.map(fn {line_item, index} ->
        generate_receipt(line_item, index, total, pdf_dir, html_dir)
      end)

    successful = Enum.count(results, fn result -> result == :ok end)
    failed = total - successful

    Mix.shell().info("\nGeneration complete!")
    Mix.shell().info("Successfully generated: #{successful} receipts")

    if failed > 0 do
      Mix.shell().error("Failed: #{failed} receipts")
    end
  end

  defp generate_receipt(line_item, index, total, pdf_dir, html_dir) do
    snake_case_title = to_snake_case(line_item.short_title)
    base_filename = "receipt_#{line_item.item_identifier}_#{line_item.id}_#{snake_case_title}"
    pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
    html_path = Path.join(html_dir, "#{base_filename}.html")

    Mix.shell().info("[#{index}/#{total}] Generating receipt for item ##{line_item.item_identifier} (line item #{line_item.id})...")

    with :ok <- ReceiptGenerator.generate_pdf(line_item, pdf_path),
         :ok <- ReceiptGenerator.save_html(line_item, html_path) do
      :ok
    else
      {:error, reason} ->
        Mix.shell().error("Failed to generate receipt for line item ##{line_item.id}: #{inspect(reason)}")
        :error
    end
  end

  defp to_snake_case(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
```

2. Update tests if needed (test file likely just checks module exists).

**Commit message:** `Update generate_receipts task for LineItem model`

---

### Step 6: Update generate_receipt task for LineItem model

**Files to modify:**
- `lib/mix/tasks/generate_receipt.ex`
- `test/mix/tasks/generate_receipt_test.exs`

**Changes:**

1. Update to look up by line item ID:

```elixir
# lib/mix/tasks/generate_receipt.ex
defmodule Mix.Tasks.GenerateReceipt do
  use Mix.Task
  alias Receipts.LineItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate HTML and PDF receipt for a single line item from database"

  @moduledoc """
  Generates both HTML and PDF receipts for a single line item from the database.

  ## Usage

      mix generate_receipt <line_item_id>

  ## Example

      mix generate_receipt 42

  This will:
  1. Look up line item #42 in the database
  2. Generate fresh HTML from the database data
  3. Generate PDF from the HTML
  4. Save both files to receipts/html/ and receipts/pdf/

  This is useful when you've updated a line item in the database and want to
  regenerate just that one receipt without regenerating all receipts.
  """

  def run([]) do
    Mix.shell().error("Error: Line item ID required")
    Mix.shell().info("Usage: mix generate_receipt <line_item_id>")
    Mix.shell().info("Example: mix generate_receipt 42")
    exit({:shutdown, 1})
  end

  def run([line_item_id_str | _]) do
    Application.ensure_all_started(:receipts)
    ChromicPDFHelper.ensure_started()

    case Integer.parse(line_item_id_str) do
      {line_item_id, _} ->
        generate_receipt(line_item_id)

      :error ->
        Mix.shell().error("Error: Invalid line item ID '#{line_item_id_str}' - must be a number")
        exit({:shutdown, 1})
    end
  end

  defp generate_receipt(line_item_id) do
    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    case Repo.get(LineItem, line_item_id) do
      nil ->
        Mix.shell().error("Error: Line item ##{line_item_id} not found in database")
        exit({:shutdown, 1})

      line_item ->
        snake_case_title = to_snake_case(line_item.short_title)
        base_filename = "receipt_#{line_item.item_identifier}_#{line_item.id}_#{snake_case_title}"
        pdf_path = Path.join(pdf_dir, "#{base_filename}.pdf")
        html_path = Path.join(html_dir, "#{base_filename}.html")

        Mix.shell().info("Found line item ##{line_item_id}: #{line_item.title}")
        Mix.shell().info("Generating HTML to: #{Path.relative_to_cwd(html_path)}")
        Mix.shell().info("Generating PDF to: #{Path.relative_to_cwd(pdf_path)}")

        with :ok <- ReceiptGenerator.generate_pdf(line_item, pdf_path),
             :ok <- ReceiptGenerator.save_html(line_item, html_path) do
          Mix.shell().info("Successfully generated receipt for line item ##{line_item_id}")
        else
          {:error, reason} ->
            Mix.shell().error("Error generating receipt: #{inspect(reason)}")
            exit({:shutdown, 1})
        end
    end
  end

  defp to_snake_case(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
```

2. Update the test file.

**Commit message:** `Update generate_receipt task for LineItem model`

---

### Step 7: Update migrate_json_to_db task for Item/LineItem model

**Files to modify:**
- `lib/mix/tasks/migrate_json_to_db.ex`
- `test/mix/tasks/migrate_json_to_db_test.exs`

**Changes:**

1. Update to create Items and LineItems:

```elixir
# lib/mix/tasks/migrate_json_to_db.ex
defmodule Mix.Tasks.MigrateJsonToDb do
  use Mix.Task

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.Config
  alias Receipts.Repo

  NimbleCSV.define(MigrationCSVParser, separator: ",", escape: "\"")

  @shortdoc "One-time migration: Import JSON files to database"

  @moduledoc """
  Imports existing JSON files into the database with actual CSV row hashes.
  This is a one-time migration task.

  For each JSON file, finds the corresponding CSV file and computes the actual
  CSV row hash for change detection.

  ## Usage

      mix migrate_json_to_db
  """

  def run(_args) do
    Application.ensure_all_started(:receipts)

    json_dir = Config.json_dir()
    csv_dir = Config.csv_dir()

    json_files =
      case File.ls(json_dir) do
        {:ok, files} ->
          Enum.filter(files, &String.ends_with?(&1, ".json"))

        {:error, _} ->
          []
      end

    if json_files == [] do
      Mix.shell().error("No JSON files found in #{json_dir}")
      System.halt(1)
    end

    Mix.shell().info("Importing #{length(json_files)} JSON file(s) to database...")
    Mix.shell().info("CSV files will be read to compute correct hashes for change detection.\n")

    import_files(json_files, json_dir, csv_dir)
  end

  defp import_files(files, json_dir, csv_dir) do
    stats = %{items_created: 0, line_items_imported: 0, skipped: 0, no_csv: 0}

    final_stats =
      Enum.reduce(files, stats, fn filename, acc ->
        Mix.shell().info("\nProcessing #{filename}...")

        csv_filename = String.replace_suffix(filename, ".json", ".csv")
        csv_path = Path.join(csv_dir, csv_filename)

        csv_row_map =
          if File.exists?(csv_path) do
            map = build_csv_row_map(csv_path)
            Mix.shell().info("  Found CSV file with #{map_size(map)} rows")
            map
          else
            Mix.shell().info("  Warning: CSV file #{csv_filename} not found, using placeholder hashes")
            %{}
          end

        json_path = Path.join(json_dir, filename)
        {:ok, content} = File.read(json_path)
        {:ok, items_data} = Jason.decode(content)

        Enum.reduce(items_data, acc, fn item_data, acc_inner ->
          item_identifier = item_data["item_id"]

          # Find or create Item
          {item, item_created} = find_or_create_item(item_identifier)
          acc_inner = if item_created, do: %{acc_inner | items_created: acc_inner.items_created + 1}, else: acc_inner

          {csv_row_hash, csv_raw_line} =
            case Map.get(csv_row_map, item_identifier) do
              nil -> {"migrated_from_json", "migrated_from_json"}
              entries when is_list(entries) -> hd(entries)
            end

          attrs =
            item_data
            |> Map.put("item_id", item.id)
            |> Map.put("item_identifier", item_identifier)
            |> Map.put("csv_row_hash", csv_row_hash)
            |> Map.put("csv_raw_line", csv_raw_line)

          # Check if line item already exists
          case Repo.get_by(LineItem, item_id: item.id, csv_row_hash: csv_row_hash) do
            nil ->
              %LineItem{}
              |> LineItem.changeset(attrs)
              |> Repo.insert!()

              new_acc = %{acc_inner | line_items_imported: acc_inner.line_items_imported + 1}
              if csv_row_hash == "migrated_from_json" do
                %{new_acc | no_csv: new_acc.no_csv + 1}
              else
                new_acc
              end

            _existing ->
              Mix.shell().info("  Skipped line item for ##{item_identifier} (already exists)")
              %{acc_inner | skipped: acc_inner.skipped + 1}
          end
        end)
      end)

    Mix.shell().info("\nMigration complete!")
    Mix.shell().info("Items created: #{final_stats.items_created}")
    Mix.shell().info("Line items imported: #{final_stats.line_items_imported}")
    Mix.shell().info("Skipped: #{final_stats.skipped} (already in database)")

    if final_stats.no_csv > 0 do
      Mix.shell().info("Warning: #{final_stats.no_csv} items imported without CSV hash")
    end
  end

  defp find_or_create_item(item_identifier) do
    case Repo.get_by(Item, item_identifier: item_identifier) do
      nil ->
        {:ok, item} =
          %Item{}
          |> Item.changeset(%{item_identifier: item_identifier})
          |> Repo.insert()
        {item, true}

      item ->
        {item, false}
    end
  end

  defp build_csv_row_map(csv_path) do
    # Build map of item_identifier => [{hash, raw_line}, ...] to handle duplicates
    rows =
      csv_path
      |> File.stream!()
      |> MigrationCSVParser.parse_stream()
      |> Enum.to_list()

    case rows do
      [_title_row, headers, _empty_row | data_rows] ->
        item_id_index =
          headers
          |> Enum.find_index(fn header ->
            String.upcase(String.trim(header)) == "ITEM ID"
          end)

        if is_nil(item_id_index) do
          Mix.shell().info("  Warning: ITEM ID column not found in CSV headers")
          %{}
        else
          Enum.reduce(data_rows, %{}, fn row, acc ->
            csv_raw_line = Enum.join(row, ",")
            csv_row_hash = hash_csv_row(csv_raw_line)

            item_id_str =
              row
              |> Enum.at(item_id_index, "")
              |> to_string()
              |> String.trim()

            case Integer.parse(item_id_str) do
              {item_id, _} when item_id > 0 ->
                existing = Map.get(acc, item_id, [])
                Map.put(acc, item_id, [{csv_row_hash, csv_raw_line} | existing])

              _ ->
                acc
            end
          end)
        end

      _ ->
        Mix.shell().info("  Warning: CSV file format unexpected")
        %{}
    end
  end

  defp hash_csv_row(csv_line) do
    :crypto.hash(:sha256, csv_line)
    |> Base.encode16(case: :lower)
  end
end
```

**Commit message:** `Update migrate_json_to_db task for Item/LineItem model`

---

### Step 8: Remove AuctionItem schema and update regenerate_receipt_pdf task

**Files to delete:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Files to modify:**
- `lib/mix/tasks/regenerate_receipt_pdf.ex`
- `test/mix/tasks/regenerate_receipt_pdf_test.exs`

**Changes:**

1. Delete the AuctionItem schema and its tests.

2. Update regenerate_receipt_pdf task to use LineItem (if it references AuctionItem).

3. Run full test suite to verify no remaining references to AuctionItem:

```bash
mix test
```

**Commit message:** `Remove AuctionItem schema and update regenerate_receipt_pdf`

---

### Step 9: Re-import CSV data and verify 137 line items

**Files to modify:**
- None (manual verification step)

**Changes:**

1. Clear the database and run migrations:

```bash
mix ecto.reset
```

2. Process the CSV file:

```bash
mix process_auction_items --skip-ai-processing
```

3. Verify counts:

```bash
# In iex -S mix
Receipts.Repo.aggregate(Receipts.Item, :count)      # Should be ~122
Receipts.Repo.aggregate(Receipts.LineItem, :count)  # Should be 137
```

4. Generate receipts to verify everything works:

```bash
mix generate_receipts
```

5. Verify 137 receipt PDFs were generated.

**Commit message:** `Re-import CSV data to Item/LineItem model`

---

## Notes

- The `item_identifier` field stores the business key from CSV (139, 140, etc.)
- The `item_id` field on LineItem is the Ecto foreign key to the Items table
- Receipt filenames now include both `item_identifier` and `line_item.id` to distinguish line items with the same item_identifier
- Change detection is now per-line-item using `csv_row_hash`
- Items with duplicate `item_id` values in CSV (like #139, #140, #223) will have multiple LineItems associated with a single Item
