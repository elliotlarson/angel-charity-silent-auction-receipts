# Implementation Plan: Database Migration with Change Detection

## Progress Checklist

- [x] Step 1: Add Ecto SQLite dependencies and configuration
- [x] Step 2: Create Repo and database setup
- [x] Step 3: Create auction_items table migration
- [x] Step 4: Convert AuctionItem to full Ecto schema
- [x] Step 5: Add change detection logic to process_auction_items
- [x] Step 6: Update generate_receipts to read from database
- [x] Step 7: Create migration task to import existing JSON files
- [x] Step 8: Remove JSON-based code and update documentation

## Overview

This migration moves from file-based storage (JSON) to a SQLite database as the source of truth for auction items. It implements intelligent change detection using SHA256 hashes to avoid reprocessing unchanged data.

## Key Design Decisions

**SQLite over PostgreSQL**: SQLite is perfect for this use case - single user, local storage, no server needed, file-based database that can be committed to git if desired.

**Ecto for Database Access**: Already using Ecto for validation, extending to full database capabilities is natural.

**SHA256 Hash for Change Detection**: Hash the raw CSV row (before processing) to detect any changes. This is fast, reliable, and works even if processed fields change due to AI variations.

**Store Original CSV Line**: Keep the raw CSV line in the database for debugging, auditing, and potential reprocessing.

**Timestamps**: Add `inserted_at` and `updated_at` to track when records were created and last modified.

**Backward Compatibility**: Provide migration task to import existing JSON files, so no data is lost.

**No File Selection for generate_receipts**: Since database is the source of truth, `generate_receipts` just reads all current items from the database.

## Implementation Steps

### Step 1: Add Ecto SQLite dependencies and configuration

**Files to modify:**
- `mix.exs`

**Changes:**

Add Ecto SQLite adapter:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:nimble_csv, "~> 1.2"},
    {:ecto, "~> 3.11"},
    {:ecto_sql, "~> 3.11"},
    {:ecto_sqlite3, "~> 0.17"},
    {:req, "~> 0.5.0"},
    {:dotenvy, "~> 0.8.0"},
    {:chromic_pdf, "~> 1.17"},
    {:number, "~> 1.0"}
  ]
end
```

Create config directory and files:

```elixir
# config/config.exs
import Config

config :receipts, Receipts.Repo,
  database: "receipts_#{config_env()}.db",
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :receipts, ecto_repos: [Receipts.Repo]

import_config "#{config_env()}.exs"
```

```elixir
# config/dev.exs
import Config
```

```elixir
# config/test.exs
import Config

config :receipts, Receipts.Repo,
  database: "receipts_test.db",
  pool: Ecto.Adapters.SQL.Sandbox
```

```elixir
# config/prod.exs
import Config
```

Add tests to verify configuration loads correctly:

```elixir
# test/receipts/config_test.exs (add to existing tests)
test "database configuration is present" do
  config = Application.get_env(:receipts, Receipts.Repo)
  assert config[:database] =~ "receipts_"
  assert config[:pool_size] == 5
end

test "ecto_repos includes Receipts.Repo" do
  repos = Application.get_env(:receipts, :ecto_repos)
  assert Receipts.Repo in repos
end
```

**Testing:**
```bash
mix deps.get
mix compile
mix test test/receipts/config_test.exs
```

**Commit message:** `Add Ecto SQLite dependencies and configuration`

---

### Step 2: Create Repo and database setup

**Files to create:**
- `lib/receipts/repo.ex`
- `lib/receipts/application.ex`
- `test/support/data_case.ex`

**Files to modify:**
- `mix.exs`
- `test/test_helper.exs`

**Changes:**

Create Repo module:

```elixir
defmodule Receipts.Repo do
  use Ecto.Repo,
    otp_app: :receipts,
    adapter: Ecto.Adapters.SQLite3
end
```

Create Application module to start Repo:

```elixir
defmodule Receipts.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Receipts.Repo
    ]

    opts = [strategy: :one_for_one, name: Receipts.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Update `mix.exs` to start application:

```elixir
def application do
  [
    extra_applications: [:logger],
    mod: {Receipts.Application, []}
  ]
end
```

Create DataCase helper for tests:

```elixir
defmodule Receipts.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Receipts.Repo
      import Ecto
      import Ecto.Query
      import Receipts.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Receipts.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Receipts.Repo, {:shared, self()})
    end

    :ok
  end
end
```

Update `test/test_helper.exs`:

```elixir
Code.require_file("support/api_fixtures_helper.exs", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Receipts.Repo, :manual)

{:ok, _} = Supervisor.start_link([ChromicPDF], strategy: :one_for_one, name: Test.Supervisor)
```

Add tests to verify Repo works:

```elixir
# test/receipts/repo_test.exs
defmodule Receipts.RepoTest do
  use ExUnit.Case

  alias Receipts.Repo

  test "Repo is configured and can connect" do
    assert Repo.config()[:database] =~ "receipts_"
    assert {:ok, _pid} = Repo.start_link()
  end
end
```

**Testing:**
```bash
mix ecto.create
mix test test/receipts/repo_test.exs
mix test
```

**Commit message:** `Create Repo and database setup`

---

### Step 3: Create auction_items table migration

**Files to create:**
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_auction_items.exs`

**Changes:**

Create migration:

```elixir
defmodule Receipts.Repo.Migrations.CreateAuctionItems do
  use Ecto.Migration

  def change do
    create table(:auction_items) do
      add :item_id, :integer, null: false
      add :short_title, :text, null: false, default: ""
      add :title, :text, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :fair_market_value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""

      # Change detection and audit fields
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:auction_items, [:item_id])
    create index(:auction_items, [:csv_row_hash])
  end
end
```

**Testing:**
```bash
mix ecto.migrate
mix ecto.rollback
mix ecto.migrate
mix test
```

**Commit message:** `Create auction_items table migration`

---

### Step 4: Convert AuctionItem to full Ecto schema

**Files to modify:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

Update AuctionItem to be a full schema:

```elixir
defmodule Receipts.AuctionItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

  @derive Jason.Encoder
  schema "auction_items" do
    field :item_id, :integer
    field :short_title, :string
    field :title, :string
    field :description, :string
    field :fair_market_value, :integer
    field :categories, :string
    field :notes, :string
    field :expiration_notice, :string
    field :csv_row_hash, :string
    field :csv_raw_line, :string

    timestamps(type: :utc_datetime)
  end

  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end

  def changeset(%__MODULE__{} = item \\ %__MODULE__{}, attrs) do
    item
    |> cast(attrs, [
      :item_id,
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
    |> validate_required([:item_id, :csv_row_hash, :csv_raw_line])
    |> unique_constraint(:item_id)
    |> apply_defaults()
    |> ensure_non_negative_integers()
    |> normalize_text_fields()
  end

  # ... rest unchanged
end
```

Update tests to use DataCase:

```elixir
defmodule Receipts.AuctionItemTest do
  use Receipts.DataCase

  alias Receipts.AuctionItem

  # Update tests to include csv_row_hash and csv_raw_line
end
```

**Testing:**
```bash
mix test test/receipts/auction_item_test.exs
mix test
```

**Commit message:** `Convert AuctionItem to full Ecto schema`

---

### Step 5: Add change detection logic to process_auction_items

**Files to modify:**
- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Update task to use database with change detection:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.AuctionItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Process auction items CSV files and save to database"

  # ... existing code ...

  defp process_file(filename, opts) do
    csv_path = Path.join(Config.csv_dir(), filename)

    Mix.shell().info("Processing #{filename}...")

    items =
      csv_path
      |> read_and_parse_csv()
      |> process_rows(opts)

    Mix.shell().info("\nProcessing complete!")
    Mix.shell().info("Total items in database: #{Repo.aggregate(AuctionItem, :count)}")
  end

  defp process_rows(rows, opts) do
    [_title_row, headers, _empty_row | data_rows] = rows

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?/1)
    total = length(valid_rows)
    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    stats = %{new: 0, updated: 0, skipped: 0}

    stats =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce(stats, fn {row, index} ->
        process_row(row, headers, index, total, skip_ai, stats)
      end)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new}")
    Mix.shell().info("  Updated items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")

    stats
  end

  defp process_row(row, headers, index, total, skip_ai, stats) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_id_str = get_column(row, find_header_index(headers, "ITEM ID"))
    item_id = String.to_integer(item_id_str)

    existing = Repo.get_by(AuctionItem, item_id: item_id)

    cond do
      is_nil(existing) ->
        # New item - process and insert
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, skip_ai: skip_ai)
        changeset = AuctionItem.changeset(%AuctionItem{}, attrs)
        {:ok, _item} = Repo.insert(changeset)
        Mix.shell().info("[#{index}/#{total}] Created item ##{item_id}")
        %{stats | new: stats.new + 1}

      existing.csv_row_hash == csv_row_hash ->
        # Unchanged - skip processing
        Mix.shell().info("[#{index}/#{total}] Skipped item ##{item_id} (unchanged)")
        %{stats | skipped: stats.skipped + 1}

      true ->
        # Changed - reprocess and update
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, skip_ai: skip_ai)
        changeset = AuctionItem.changeset(existing, attrs)
        {:ok, _item} = Repo.update(changeset)
        Mix.shell().info("[#{index}/#{total}] Updated item ##{item_id}")
        %{stats | updated: stats.updated + 1}
    end
  end

  defp hash_csv_row(csv_line) do
    :crypto.hash(:sha256, csv_line)
    |> Base.encode16(case: :lower)
  end

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, opts) do
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
            {field, ""} when field in [:item_id, :fair_market_value] -> nil
            _ -> value
          end

        Map.put(acc, field_name, normalized_value)
      end)

    attrs
    |> Map.put(:csv_row_hash, csv_row_hash)
    |> Map.put(:csv_raw_line, csv_raw_line)
    |> AIDescriptionProcessor.process(opts)
  end

  # Remove: build_item (replaced by build_attrs)
end
```

Update tests to use database:

```elixir
defmodule Mix.Tasks.ProcessAuctionItemsTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  # Update tests to verify database operations
  # Test change detection logic
end
```

**Testing:**
```bash
mix test test/mix/tasks/process_auction_items_test.exs
mix test
```

**Commit message:** `Add change detection logic to process_auction_items`

---

### Step 6: Update generate_receipts to read from database

**Files to modify:**
- `lib/mix/tasks/generate_receipts.ex`
- `test/mix/tasks/generate_receipts_test.exs`

**Changes:**

Simplify to read from database:

```elixir
defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.AuctionItem
  alias Receipts.ReceiptGenerator
  alias Receipts.ChromicPDFHelper
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "Generate PDF receipts for all auction items"

  def run(_args) do
    ChromicPDFHelper.ensure_started()

    pdf_dir = Config.pdf_dir()
    html_dir = Config.html_dir()

    File.mkdir_p!(pdf_dir)
    File.mkdir_p!(html_dir)

    items = Repo.all(AuctionItem)
    total = length(items)

    Mix.shell().info("Generating receipts for #{total} auction items...")

    results =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        generate_receipt(item, index, total, pdf_dir, html_dir)
      end)

    successful = Enum.count(results, fn result -> result == :ok end)
    failed = total - successful

    Mix.shell().info("\nGeneration complete!")
    Mix.shell().info("Successfully generated: #{successful} receipts")

    if failed > 0 do
      Mix.shell().error("Failed: #{failed} receipts")
    end
  end

  # Remove: list_json_files, prompt_file_selection, load_auction_items
  # Keep: generate_receipt, to_snake_case (unchanged)
end
```

Update tests:

```elixir
defmodule Mix.Tasks.GenerateReceiptsTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  # Insert test data into database instead of creating JSON files
  # Remove file selection tests
end
```

**Testing:**
```bash
mix test test/mix/tasks/generate_receipts_test.exs
mix test
```

**Commit message:** `Update generate_receipts to read from database`

---

### Step 7: Create migration task to import existing JSON files

**Files to create:**
- `lib/mix/tasks/migrate_json_to_db.ex`

**Changes:**

Create one-time migration task:

```elixir
defmodule Mix.Tasks.MigrateJsonToDb do
  use Mix.Task

  alias Receipts.AuctionItem
  alias Receipts.Config
  alias Receipts.Repo

  @shortdoc "One-time migration: Import JSON files to database"

  @moduledoc """
  Imports existing JSON files into the database.
  This is a one-time migration task.

  ## Usage

      mix migrate_json_to_db
  """

  def run(_args) do
    Application.ensure_all_started(:receipts)

    json_dir = Config.json_dir()

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

    Mix.shell().info("Found #{length(json_files)} JSON file(s)")
    Mix.shell().info("This will import all items into the database.")

    if Mix.shell().yes?("Continue?") do
      import_files(json_files, json_dir)
    else
      Mix.shell().info("Migration cancelled")
    end
  end

  defp import_files(files, json_dir) do
    stats = %{imported: 0, skipped: 0}

    final_stats =
      Enum.reduce(files, stats, fn filename, acc ->
        Mix.shell().info("\nProcessing #{filename}...")
        path = Path.join(json_dir, filename)
        {:ok, content} = File.read(path)
        {:ok, items_data} = Jason.decode(content)

        Enum.reduce(items_data, acc, fn item_data, acc_inner ->
          # Create a synthetic hash since we don't have original CSV
          csv_raw_line = "migrated_from_json"
          csv_row_hash = hash_line(Jason.encode!(item_data))

          attrs =
            item_data
            |> Map.put("csv_row_hash", csv_row_hash)
            |> Map.put("csv_raw_line", csv_raw_line)

          case Repo.get_by(AuctionItem, item_id: attrs["item_id"]) do
            nil ->
              %AuctionItem{}
              |> AuctionItem.changeset(attrs)
              |> Repo.insert!()

              %{acc_inner | imported: acc_inner.imported + 1}

            _existing ->
              Mix.shell().info("  Skipped item ##{attrs["item_id"]} (already exists)")
              %{acc_inner | skipped: acc_inner.skipped + 1}
          end
        end)
      end)

    Mix.shell().info("\nMigration complete!")
    Mix.shell().info("Imported: #{final_stats.imported} items")
    Mix.shell().info("Skipped: #{final_stats.skipped} items (already in database)")
  end

  defp hash_line(line) do
    :crypto.hash(:sha256, line)
    |> Base.encode16(case: :lower)
  end
end
```

Add tests for the migration task:

```elixir
# test/mix/tasks/migrate_json_to_db_test.exs
defmodule Mix.Tasks.MigrateJsonToDbTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  test "imports JSON files to database" do
    # Create test JSON file
    json_dir = Receipts.Config.json_dir()
    File.mkdir_p!(json_dir)

    test_data = [
      %{
        "item_id" => 1,
        "short_title" => "Test",
        "title" => "Test Item",
        "description" => "Test description",
        "fair_market_value" => 100,
        "categories" => "TEST",
        "notes" => "Test notes",
        "expiration_notice" => "No expiration"
      }
    ]

    json_path = Path.join(json_dir, "test.json")
    File.write!(json_path, Jason.encode!(test_data))

    # Run migration with auto-yes
    capture_io([input: "y\n"], fn ->
      Mix.Tasks.MigrateJsonToDb.run([])
    end)

    # Verify item was imported
    item = Receipts.Repo.get_by(Receipts.AuctionItem, item_id: 1)
    assert item.title == "Test Item"
    assert item.csv_raw_line == "migrated_from_json"

    # Cleanup
    File.rm!(json_path)
  end
end
```

**Testing:**
```bash
mix test test/mix/tasks/migrate_json_to_db_test.exs
mix test
```

**Commit message:** `Create migration task to import JSON files to database`

---

### Step 8: Remove JSON-based code and update documentation

**Files to modify:**
- `README.md`
- `.claude/CLAUDE.md`
- `.gitignore`

**Files to remove:**
- `db/auction_items/json/` directory (keep for reference, add to .gitignore)

**Changes:**

Update README workflow:

```markdown
## Quick Start Workflow

When you receive a new CSV file from Angel Charity, follow these steps:

1. **Place CSV file** in `db/auction_items/csv/`
2. **Process CSV to database** with AI extraction:

   ```bash
   mix process_auction_items
   ```

   - Select the CSV file from the list
   - AI will extract expiration dates and special notes
   - Changes detected automatically (unchanged items skipped)
   - Data saved to SQLite database

3. **Generate PDF and HTML receipts**:

   ```bash
   mix generate_receipts
   ```

   - Reads all items from database
   - Generates PDFs in `receipts/pdf/`
   - Generates HTML in `receipts/html/`

4. **Review outputs**:
   - Check `receipts/pdf/` for printable PDFs
   - Check `receipts/html/` for web-viewable versions
```

Update .gitignore:

```
# Database
*.db
*.db-*

# Deprecated - using database now
db/auction_items/json/
```

Update CLAUDE.md:

```markdown
### Data Storage

- `db/auction_items/csv/` - Source CSV files with auction item data
- `receipts_dev.db` - SQLite database (source of truth for auction items)
- `db/auction_items/cache/` - AI processing cache (SHA256-named JSON files)
- `receipts/pdf/` - Generated PDF receipts
- `receipts/html/` - Generated HTML receipts
```

**Testing:**
```bash
mix test
```

**Commit message:** `Update documentation for database-based workflow`

---

## Notes

**Migration Strategy**: Existing JSON files can be imported using `mix migrate_json_to_db`. After migration, JSON files are no longer used but can be kept for historical reference.

**Change Detection Performance**: SHA256 hashing is fast. For 137 items, hash computation takes milliseconds. The benefit of skipping AI processing for unchanged items far outweighs the hashing cost.

**Database File**: `receipts_dev.db` is created in the project root. Consider adding to `.gitignore` unless you want to commit it.

**AI Cache Still Useful**: The `ProcessingCache` module remains useful even with database change detection, as it caches AI responses across different CSV imports.

**Backward Compatibility**: The `AuctionItem.new/1` function still works for creating structs without database persistence (useful in tests).

**Testing Strategy**: Use `Ecto.Adapters.SQL.Sandbox` for isolated test database transactions. Each test gets a clean database state.

**Item ID as Business Key**: Using `item_id` as unique constraint since it's the business identifier from the CSV. Database primary key (`id`) is auto-generated but not used.
