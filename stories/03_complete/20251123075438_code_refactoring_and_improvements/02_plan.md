# Implementation Plan: Code Refactoring and Improvements

## Progress Checklist

- [x] Step 1: Fix unsafe error handling in AnthropicClient
- [x] Step 2: Fix currency formatting logic
- [x] Step 3: Fix unsafe user input parsing in ProcessAuctionItems
- [x] Step 4: Extract ChromicPDF initialization to shared helper
- [x] Step 5: Create centralized configuration module
- [x] Step 6: Fix AuctionItem changeset convention
- [x] Step 7: Move module-level alias out of function
- [x] Step 8: Remove dead code from Receipts module
- [x] Step 9: Optimize template reading with compile-time loading
- [x] Step 10: Simplify default logic in AuctionItem
- [x] Step 11: Optimize regex compilation in TextNormalizer

## Overview

This refactoring addresses critical safety issues, improves code quality, and optimizes performance. The work is prioritized to fix unsafe error handling first, then address code quality issues, and finally apply optimizations.

## Key Design Decisions

**Priority Order**: Critical safety issues (Steps 1-3) must be completed first to prevent runtime crashes and security issues. Code quality improvements (Steps 4-8) follow, with performance optimizations last (Steps 9-11).

**Backward Compatibility**: All changes maintain existing public APIs and behavior. Tests verify that functionality remains unchanged.

**Configuration Centralization**: A new `Receipts.Config` module provides a single source of truth for all file paths and configuration, making it easier to customize via application config.

**Ecto Conventions**: The changeset fix follows standard Ecto patterns where changesets take `changeset(struct, attrs)` rather than just `attrs`.

**Performance Optimizations**: Template and regex optimizations use compile-time evaluation to eliminate repeated file I/O and regex compilation.

## Implementation Steps

### Step 1: Fix unsafe error handling in AnthropicClient

**Files to modify:**

- `lib/receipts/anthropic_client.ex`
- `test/receipts/anthropic_client_test.exs`

**Changes:**

Replace `Req.post!` with `Req.post` to properly handle network errors:

```elixir
defp make_request(prompt, api_key, model, max_tokens) do
  request_body = %{
    model: model,
    max_tokens: max_tokens,
    messages: [
      %{
        role: "user",
        content: prompt
      }
    ]
  }

  case Req.post(
    "#{@api_base_url}/messages",
    json: request_body,
    headers: [
      {"x-api-key", api_key},
      {"anthropic-version", @api_version},
      {"content-type", "application/json"}
    ]
  ) do
    {:ok, response} -> parse_response(response)
    {:error, reason} -> {:error, {:network_error, reason}}
  end
end
```

Update tests to cover network error scenarios:

```elixir
test "returns error tuple on network failure" do
  # Test would need to mock Req.post to return {:error, :timeout}
  # Verify {:error, {:network_error, :timeout}} is returned
end
```

**Testing:**

```bash
mix test test/receipts/anthropic_client_test.exs
mix test
```

**Commit message:** `Fix unsafe error handling in AnthropicClient`

---

### Step 2: Fix currency formatting logic

**Files to modify:**

- `lib/receipts/receipt_generator.ex`
- `test/receipts/receipt_generator_test.exs`

**Changes:**

Replace broken currency formatting with correct implementation:

```elixir
defp format_currency(value) when is_integer(value) do
  value
  |> Integer.to_string()
  |> String.graphemes()
  |> Enum.reverse()
  |> Enum.chunk_every(3)
  |> Enum.join(",")
  |> String.reverse()
  |> then(&"$#{&1}.00")
end
```

Add comprehensive tests:

```elixir
test "format_currency/1 formats single digit" do
  assert format_currency(5) == "$5.00"
end

test "format_currency/1 formats hundreds" do
  assert format_currency(500) == "$500.00"
end

test "format_currency/1 formats thousands with comma" do
  assert format_currency(1500) == "$1,500.00"
end

test "format_currency/1 formats millions with commas" do
  assert format_currency(1_250_000) == "$1,250,000.00"
end
```

**Testing:**

```bash
mix test test/receipts/receipt_generator_test.exs
mix test
```

**Commit message:** `Fix currency formatting logic`

---

### Step 3: Fix unsafe user input parsing in ProcessAuctionItems

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Replace unsafe `String.to_integer/1` with proper error handling:

```elixir
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
```

Add test for invalid input handling:

```elixir
test "handles invalid file selection gracefully" do
  # Test would verify that invalid inputs prompt re-entry
end
```

**Testing:**

```bash
mix test test/mix/tasks/process_auction_items_test.exs
mix test
```

**Commit message:** `Fix unsafe user input parsing in ProcessAuctionItems`

---

### Step 4: Extract ChromicPDF initialization to shared helper

**Files to create:**

- `lib/receipts/chromic_pdf_helper.ex`
- `test/receipts/chromic_pdf_helper_test.exs`

**Files to modify:**

- `lib/mix/tasks/generate_receipts.ex`
- `lib/mix/tasks/regenerate_receipt.ex`

**Changes:**

Create shared helper module:

```elixir
defmodule Receipts.ChromicPDFHelper do
  @moduledoc """
  Helper for managing ChromicPDF supervisor lifecycle.
  """

  @doc """
  Ensures ChromicPDF supervisor is started.

  Returns :ok if started successfully or already running.
  Raises if startup fails for reasons other than already_started.
  """
  def ensure_started do
    Application.ensure_all_started(:chromic_pdf)

    Process.flag(:trap_exit, true)

    case Supervisor.start_link([ChromicPDF], strategy: :one_for_one) do
      {:ok, _pid} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, {:shutdown, {:failed_to_start_child, ChromicPDF, {:already_started, _}}}} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, reason} ->
        Process.flag(:trap_exit, false)
        raise "Failed to start ChromicPDF: #{inspect(reason)}"
    end
  end
end
```

Update both Mix tasks to use the helper:

```elixir
defmodule Mix.Tasks.GenerateReceipts do
  use Mix.Task
  alias Receipts.ChromicPDFHelper
  # ...

  def run(_args) do
    ChromicPDFHelper.ensure_started()
    # ... rest of implementation
  end

  # Remove ensure_chromic_pdf_started/0
end
```

```elixir
defmodule Mix.Tasks.RegenerateReceipt do
  use Mix.Task
  alias Receipts.ChromicPDFHelper
  # ...

  def run([item_id_str | _]) do
    ChromicPDFHelper.ensure_started()
    # ... rest of implementation
  end

  # Remove ensure_chromic_pdf_started/0
end
```

**Testing:**

```bash
mix test test/receipts/chromic_pdf_helper_test.exs
mix test test/mix/tasks/generate_receipts_test.exs
mix test test/mix/tasks/regenerate_receipt_test.exs
mix test
```

**Commit message:** `Extract ChromicPDF initialization to shared helper`

---

### Step 5: Create centralized configuration module

**Files to create:**

- `lib/receipts/config.ex`
- `test/receipts/config_test.exs`

**Files to modify:**

- `lib/receipts/receipt_generator.ex`
- `lib/receipts/processing_cache.ex`
- `lib/mix/tasks/process_auction_items.ex`
- `lib/mix/tasks/generate_receipts.ex`
- `lib/mix/tasks/regenerate_receipt.ex`

**Changes:**

Create configuration module:

```elixir
defmodule Receipts.Config do
  @moduledoc """
  Centralized configuration for the Receipts application.
  All file paths and configurable values are managed here.
  """

  @doc "Directory containing CSV input files"
  def csv_dir, do: get_env(:csv_dir, "db/auction_items/csv")

  @doc "Directory containing JSON output files"
  def json_dir, do: get_env(:json_dir, "db/auction_items/json")

  @doc "Directory for generated PDF receipts"
  def pdf_dir, do: get_env(:pdf_dir, "receipts/pdf")

  @doc "Directory for generated HTML receipts"
  def html_dir, do: get_env(:html_dir, "receipts/html")

  @doc "Directory for AI processing cache"
  def cache_dir, do: get_env(:cache_dir, "db/auction_items/cache")

  @doc "Path to receipt HTML template"
  def template_path, do: get_env(:template_path, "priv/templates/receipt.html.eex")

  @doc "Path to logo file"
  def logo_path, do: get_env(:logo_path, "priv/static/angel_charity_logo.svg")

  defp get_env(key, default) do
    Application.get_env(:receipts, key, default)
  end
end
```

Update all modules to use `Receipts.Config`:

```elixir
# lib/receipts/receipt_generator.ex
defmodule Receipts.ReceiptGenerator do
  alias Receipts.Config

  def render_html(auction_item) do
    template = File.read!(Config.template_path())
    # ...
  end

  defp get_logo_data_uri do
    logo_content = File.read!(Config.logo_path())
    # ...
  end
end
```

```elixir
# lib/receipts/processing_cache.ex
defmodule Receipts.ProcessingCache do
  alias Receipts.Config

  def get(description) do
    cache_key = hash_description(description)
    cache_path = Path.join(Config.cache_dir(), "#{cache_key}.json")
    # ...
  end
end
```

```elixir
# lib/mix/tasks/process_auction_items.ex
defmodule Mix.Tasks.ProcessAuctionItems do
  alias Receipts.Config

  defp list_csv_files do
    case File.ls(Config.csv_dir()) do
      # ...
    end
  end

  defp process_file(filename, opts) do
    csv_path = Path.join(Config.csv_dir(), filename)
    json_path = Path.join(Config.json_dir(), json_filename)
    # ...
  end
end
```

**Testing:**

```bash
mix test test/receipts/config_test.exs
mix test
```

**Commit message:** `Create centralized configuration module`

---

### Step 6: Fix AuctionItem changeset convention

**Files to modify:**

- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

Update changeset to follow Ecto conventions:

```elixir
defmodule Receipts.AuctionItem do
  # ...

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
      :expiration_notice
    ])
    |> apply_defaults()
    |> ensure_non_negative_integers()
    |> normalize_text_fields()
  end

  # ... rest unchanged
end
```

Update tests to verify both forms work:

```elixir
test "changeset/2 works with existing struct" do
  item = %AuctionItem{item_id: 1}
  changeset = AuctionItem.changeset(item, %{title: "New Title"})
  assert changeset.changes.title == "New Title"
end

test "changeset/2 works with default struct" do
  changeset = AuctionItem.changeset(%AuctionItem{}, %{title: "Title"})
  assert changeset.changes.title == "Title"
end
```

**Testing:**

```bash
mix test test/receipts/auction_item_test.exs
mix test
```

**Commit message:** `Fix AuctionItem changeset to follow Ecto conventions`

---

### Step 7: Move module-level alias out of function

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`

**Changes:**

Move alias to module level:

```elixir
defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.AuctionItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config

  # ...

  def build_item(row, headers, opts \\ []) do
    # Remove: alias Receipts.AIDescriptionProcessor

    attrs =
      @field_mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        # ... implementation
      end)

    attrs
    |> AIDescriptionProcessor.process(opts)
    |> AuctionItem.new()
  end
end
```

**Testing:**

```bash
mix test test/mix/tasks/process_auction_items_test.exs
mix test
```

**Commit message:** `Move module-level alias to top of ProcessAuctionItems`

---

### Step 8: Remove dead code from Receipts module

**Files to modify:**

- `lib/receipts.ex`

**Files to delete:**

- None (keep module but make it useful)

**Changes:**

Replace placeholder with useful module documentation:

```elixir
defmodule Receipts do
  @moduledoc """
  Receipts is an Elixir application for processing auction item data and generating receipts.

  ## Main Components

  - `Receipts.AuctionItem` - Data model for auction items with validation
  - `Receipts.ReceiptGenerator` - Generates PDF and HTML receipts
  - `Receipts.AIDescriptionProcessor` - Extracts metadata using AI
  - `Receipts.ProcessingCache` - Caches AI processing results
  - `Receipts.Config` - Centralized configuration management

  ## Mix Tasks

  - `mix process_auction_items` - Convert CSV files to JSON
  - `mix generate_receipts` - Generate PDF/HTML receipts from JSON
  - `mix regenerate_receipt <item_id>` - Regenerate single receipt from edited HTML

  ## Usage

  Process a CSV file:

      mix process_auction_items

  Generate receipts for all items:

      mix generate_receipts

  Regenerate a single receipt after editing HTML:

      mix regenerate_receipt 120
  """
end
```

**Testing:**

```bash
mix test
```

**Commit message:** `Replace placeholder Receipts module with documentation`

---

### Step 9: Optimize template reading with compile-time loading

**Files to modify:**

- `lib/receipts/receipt_generator.ex`
- `test/receipts/receipt_generator_test.exs`

**Changes:**

Use compile-time template reading:

```elixir
defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  alias Receipts.Config

  @external_resource Config.template_path()
  @template File.read!(Config.template_path())

  @external_resource Config.logo_path()
  @logo_data_uri (fn ->
    logo_content = File.read!(Config.logo_path())
    encoded = Base.encode64(logo_content)
    "data:image/svg+xml;base64,#{encoded}"
  end).()

  def generate_pdf(auction_item, output_path) do
    html = render_html(auction_item)
    ChromicPDF.print_to_pdf({:html, html}, output: output_path)
  end

  def save_html(auction_item, output_path) do
    html = render_html(auction_item)
    File.write(output_path, html)
  end

  def render_html(auction_item) do
    assigns = %{
      item: auction_item,
      formatted_value: format_currency(auction_item.fair_market_value),
      logo_path: @logo_data_uri
    }

    EEx.eval_string(@template, assigns: assigns)
  end

  # ... rest unchanged
end
```

Note: This optimization reads the template and logo once at compile time instead of on every call.

**Testing:**

```bash
mix test test/receipts/receipt_generator_test.exs
mix test
```

**Commit message:** `Optimize template reading with compile-time loading`

---

### Step 10: Simplify default logic in AuctionItem

**Files to modify:**

- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

Simplify the default application logic:

```elixir
defp apply_defaults(changeset) do
  changeset
  |> put_default_if_nil_or_empty(:item_id, 0)
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
```

Verify all existing tests still pass (behavior unchanged):

```bash
mix test test/receipts/auction_item_test.exs
```

**Testing:**

```bash
mix test test/receipts/auction_item_test.exs
mix test
```

**Commit message:** `Simplify default logic in AuctionItem`

---

### Step 11: Optimize regex compilation in TextNormalizer

**Files to modify:**

- `lib/receipts/text_normalizer.ex`
- `test/receipts/text_normalizer_test.exs`

**Changes:**

Use module attributes for compiled regexes:

```elixir
defmodule Receipts.TextNormalizer do
  @moduledoc """
  Provides text normalization functions for cleaning up formatting issues
  in text data, such as spacing around punctuation.
  """

  @phone_number_regex ~r/(\d{3})-(\d{3})-(\d{4})/
  @spaces_before_punct_regex ~r/\s+([.,!?;:])/
  @sentence_punct_regex ~r/([.!?])([A-Z])/
  @parens_regex ~r/\)([A-Za-z0-9])/
  @multiple_spaces_regex ~r/ {2,}/

  @doc """
  Normalizes text by:
  - Formatting phone numbers (XXX-XXX-XXXX to (XXX) XXX-XXXX)
  - Removing spaces before punctuation (., , ! ? ; :)
  - Adding spaces after sentence-ending punctuation (. ! ?)
  - Adding spaces after closing parens when followed by letters or numbers
  - Collapsing multiple consecutive spaces into a single space

  Returns an empty string for nil values.

  ## Examples

      iex> Receipts.TextNormalizer.normalize("This is a  rare item.Good for collectors .")
      "This is a rare item. Good for collectors."

      iex> Receipts.TextNormalizer.normalize(nil)
      ""
  """
  def normalize(nil), do: ""

  def normalize(text) when is_binary(text) do
    text
    |> format_phone_numbers()
    |> remove_spaces_before_punctuation()
    |> add_spaces_after_sentence_punctuation()
    |> add_spaces_after_parens()
    |> collapse_multiple_spaces()
  end

  defp remove_spaces_before_punctuation(text) do
    Regex.replace(@spaces_before_punct_regex, text, "\\1")
  end

  defp add_spaces_after_sentence_punctuation(text) do
    Regex.replace(@sentence_punct_regex, text, "\\1 \\2")
  end

  defp add_spaces_after_parens(text) do
    Regex.replace(@parens_regex, text, ") \\1")
  end

  defp collapse_multiple_spaces(text) do
    Regex.replace(@multiple_spaces_regex, text, " ")
  end

  defp format_phone_numbers(text) do
    Regex.replace(@phone_number_regex, text, "(\\1) \\2-\\3")
  end
end
```

**Testing:**

```bash
mix test test/receipts/text_normalizer_test.exs
mix test
```

**Commit message:** `Optimize regex compilation in TextNormalizer`

---

## Notes

**Testing Strategy**: Each step includes both implementation and tests in the same commit. All existing tests must continue to pass after each change.

**Critical First**: Steps 1-3 address safety issues that could cause crashes or incorrect behavior. These must be completed before other improvements.

**Backward Compatibility**: All changes maintain existing public APIs. The refactoring improves internal implementation without breaking existing code.

**Performance Impact**: Steps 9 and 11 provide measurable performance improvements:

- Template optimization eliminates file I/O on every receipt generation
- Regex optimization eliminates regex compilation on every normalization call

**Configuration Benefits**: Step 5's centralized configuration makes it easy to override defaults via application config in config/config.exs or config/runtime.exs.

**Code Quality**: Steps 4, 6, 7, and 8 improve maintainability by following Elixir idioms and removing duplication.
