# Implementation Plan: AI-Based Description Field Extraction

## Progress Checklist

- [x] Step 1: Add Req HTTP client dependency
- [x] Step 2: Create runtime configuration for Anthropic API key
- [x] Step 3: Add .env file to .gitignore
- [x] Step 4: Create Anthropic API client module
- [x] Step 5: Create description processor module
- [x] Step 6: Integrate description processing into Mix task
- [x] Step 7: Add processing cache to avoid redundant API calls

## Overview

We're adding AI-based extraction of expiration dates and special notes from auction item descriptions. The system will use the Anthropic API (Claude Haiku) to intelligently parse descriptions and extract:

- Expiration information -> `expiration_notice` field
- Special notes/instructions -> `notes` field
- Clean description -> `description` field (with extracted content removed)

This will be integrated into the existing `mix process_auction_items` task, making it fully automated and repeatable for new/updated auction data.

## Key Design Decisions

1. **API Client**: Using `Req` library (modern, ergonomic HTTP client for Elixir)
2. **Model**: Claude Haiku for cost-effectiveness and speed (~$0.01-0.05 per item)
3. **Configuration**: Standard Elixir `config/runtime.exs` with environment variables
4. **Integration Point**: Process descriptions during `build_item/2` in the Mix task
5. **Caching**: Store processed results in `db/auction_items/cache/` to avoid reprocessing unchanged items
6. **Flags**: Add `--skip-ai-processing` flag to bypass API calls when not needed
7. **Error Handling**: Log failures but continue processing other items (graceful degradation)

## Implementation Steps

### Step 1: Add Req HTTP client dependency

**Files to modify:**

- `mix.exs`

**Changes:**

Add the `req` dependency to the deps list:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:nimble_csv, "~> 1.2"},
    {:ecto, "~> 3.11"},
    {:req, "~> 0.5.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependency.

**Test:**
Verify dependency is downloaded:

```bash
mix deps.get
mix compile
```

**Commit message:** `Add Req HTTP client dependency`

---

### Step 2: Create runtime configuration for Anthropic API key

**Files to create:**

- `config/runtime.exs`

**Changes:**

Create `config/runtime.exs` to load the API key from environment variables:

```elixir
import Config

config :receipts,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
```

**Test:**
Create a simple test file `test/config_test.exs`:

```elixir
defmodule ConfigTest do
  use ExUnit.Case

  test "anthropic_api_key is configurable" do
    # Config should be nil when env var not set, or a string when set
    api_key = Application.get_env(:receipts, :anthropic_api_key)
    assert is_nil(api_key) or is_binary(api_key)
  end
end
```

Run:

```bash
mix test test/config_test.exs
```

**Commit message:** `Create runtime configuration for Anthropic API key`

---

### Step 3: Add .env file to .gitignore

**Files to modify:**

- `.gitignore`

**Changes:**

Add `.env` to the gitignore file to prevent committing API keys:

```gitignore
# Environment variables
.env
```

**Test:**
Verify .gitignore works:

```bash
touch .env
git status  # Should not show .env as untracked
```

**Commit message:** `Add .env file to .gitignore`

---

### Step 4: Create Anthropic API client module

**Files to create:**

- `lib/receipts/anthropic_client.ex`
- `test/receipts/anthropic_client_test.exs`

**Changes:**

Create the API client module:

```elixir
defmodule Receipts.AnthropicClient do
  @moduledoc """
  Client for interacting with the Anthropic API.
  """

  @api_base_url "https://api.anthropic.com/v1"
  @model "claude-haiku-4-20250514"
  @api_version "2023-06-01"

  def extract_fields(description) do
    api_key = Application.get_env(:receipts, :anthropic_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      make_request(description, api_key)
    end
  end

  defp make_request(description, api_key) do
    prompt = build_prompt(description)

    request_body = %{
      model: @model,
      max_tokens: 1024,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ]
    }

    response =
      Req.post!(
        "#{@api_base_url}/messages",
        json: request_body,
        headers: [
          {"x-api-key", api_key},
          {"anthropic-version", @api_version},
          {"content-type", "application/json"}
        ]
      )

    parse_response(response)
  end

  defp build_prompt(description) do
    """
    Analyze the following auction item description and extract any expiration dates/notices and special notes/instructions.

    Description: #{description}

    Please respond with ONLY a JSON object in this exact format (no markdown, no extra text):
    {
      "expiration_notice": "extracted expiration info or empty string",
      "notes": "extracted special notes/instructions or empty string",
      "description": "the description with expiration and notes removed"
    }

    Guidelines:
    - expiration_notice: Any text about expiration dates, validity periods, or time limits
    - notes: Special instructions like "call ahead", "out of town charges apply", "schedule with...", contact info, restrictions
    - description: The original description minus the extracted content
    - Use empty strings "" if nothing to extract
    - Keep the description clean and focused on describing the item itself
    """
  end

  defp parse_response(%{status: 200, body: body}) do
    case body do
      %{"content" => [%{"text" => json_text} | _]} ->
        case Jason.decode(json_text) do
          {:ok, %{"expiration_notice" => exp, "notes" => notes, "description" => desc}} ->
            {:ok, %{expiration_notice: exp, notes: notes, description: desc}}

          _ ->
            {:error, :invalid_response_format}
        end

      _ ->
        {:error, :unexpected_response_structure}
    end
  end

  defp parse_response(%{status: status, body: body}) do
    {:error, {:api_error, status, body}}
  end
end
```

Create test file:

```elixir
defmodule Receipts.AnthropicClientTest do
  use ExUnit.Case

  alias Receipts.AnthropicClient

  describe "extract_fields/1" do
    test "returns error when API key is not configured" do
      Application.put_env(:receipts, :anthropic_api_key, nil)
      result = AnthropicClient.extract_fields("Test description")
      assert result == {:error, :missing_api_key}
    end

    test "returns error when API key is empty string" do
      Application.put_env(:receipts, :anthropic_api_key, "")
      result = AnthropicClient.extract_fields("Test description")
      assert result == {:error, :missing_api_key}
    end
  end
end
```

Run:

```bash
mix test test/receipts/anthropic_client_test.exs
```

**Commit message:** `Create Anthropic API client module`

---

### Step 5: Create description processor module

**Files to create:**

- `lib/receipts/description_processor.ex`
- `test/receipts/description_processor_test.exs`

**Changes:**

Create the processor module that orchestrates the extraction:

```elixir
defmodule Receipts.DescriptionProcessor do
  @moduledoc """
  Processes auction item descriptions using AI to extract
  expiration notices and special notes.
  """

  alias Receipts.AnthropicClient
  require Logger

  def process(attrs, opts \\ []) do
    skip_processing = Keyword.get(opts, :skip_ai_processing, false)
    description = Map.get(attrs, :description, "")

    if skip_processing or description == "" do
      attrs
    else
      process_with_ai(attrs, description)
    end
  end

  defp process_with_ai(attrs, description) do
    case AnthropicClient.extract_fields(description) do
      {:ok, %{expiration_notice: exp, notes: notes, description: clean_desc}} ->
        Logger.info("Successfully processed description for item #{attrs[:item_id]}")

        attrs
        |> put_if_present(:expiration_notice, exp)
        |> put_if_present(:notes, notes)
        |> put_if_present(:description, clean_desc)

      {:error, reason} ->
        Logger.warning(
          "Failed to process description for item #{attrs[:item_id]}: #{inspect(reason)}"
        )

        attrs
    end
  end

  defp put_if_present(attrs, _key, ""), do: attrs
  defp put_if_present(attrs, key, value), do: Map.put(attrs, key, value)
end
```

Create test file:

```elixir
defmodule Receipts.DescriptionProcessorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Receipts.DescriptionProcessor

  describe "process/2" do
    test "returns attrs unchanged when skip_ai_processing is true" do
      attrs = %{
        item_id: "123",
        description: "Test description with expiration info"
      }

      result = DescriptionProcessor.process(attrs, skip_ai_processing: true)
      assert result == attrs
    end

    test "returns attrs unchanged when description is empty" do
      attrs = %{item_id: "123", description: ""}
      result = DescriptionProcessor.process(attrs)
      assert result == attrs
    end

    test "logs warning and returns original attrs when API call fails" do
      Application.put_env(:receipts, :anthropic_api_key, nil)

      attrs = %{
        item_id: "123",
        description: "Test description"
      }

      log =
        capture_log(fn ->
          result = DescriptionProcessor.process(attrs)
          assert result == attrs
        end)

      assert log =~ "Failed to process description"
      assert log =~ "item 123"
    end
  end
end
```

Run:

```bash
mix test test/receipts/description_processor_test.exs
```

**Commit message:** `Create description processor module`

---

### Step 6: Integrate description processing into Mix task

**Files to modify:**

- `lib/mix/tasks/process_auction_items.ex`
- `test/mix/tasks/process_auction_items_test.exs`

**Changes:**

Update the Mix task to support AI processing:

1. Add command-line switches:

```elixir
def run(args) do
  {opts, _, _} =
    OptionParser.parse(args,
      switches: [skip_ai_processing: :boolean],
      aliases: [s: :skip_ai_processing]
    )

  csv_files = list_csv_files()

  case csv_files do
    [] ->
      Mix.shell().error("No CSV files found in #{@csv_dir}")

    files ->
      selected_file = prompt_file_selection(files)
      process_file(selected_file, opts)
  end
end
```

2. Update `process_file/2` to pass options:

```elixir
defp process_file(filename, opts) do
  csv_path = Path.join(@csv_dir, filename)
  json_filename = Path.basename(filename, ".csv") <> ".json"
  json_path = Path.join(@json_dir, json_filename)

  skip_ai = Keyword.get(opts, :skip_ai_processing, false)

  unless skip_ai do
    Mix.shell().info("AI processing enabled - this may take a few minutes...")
  end

  items =
    csv_path
    |> read_and_parse_csv()
    |> clean_data(opts)

  json_content = Jason.encode!(items, pretty: true)
  File.write!(json_path, json_content)

  Mix.shell().info("Successfully processed #{length(items)} items")
  Mix.shell().info("Output saved to: #{json_path}")
end
```

3. Update `clean_data/2` to accept and pass options:

```elixir
def clean_data(rows, opts \\ []) do
  [_title_row, headers, _empty_row | data_rows] = rows

  data_rows
  |> Enum.reject(&is_placeholder_row?/1)
  |> Enum.map(&build_item(&1, headers, opts))
end
```

4. Update `build_item/3` to process descriptions:

```elixir
def build_item(row, headers, opts \\ []) do
  alias Receipts.DescriptionProcessor

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
  |> DescriptionProcessor.process(opts)
  |> AuctionItem.new()
end
```

Update the test file to handle the new options:

```elixir
# Add to existing test file
test "build_item skips AI processing when flag is set" do
  row = ["Y", "103", "Short", "", "Title", "", "Description", "", "1200", "480", "100", "1", "HOME", "", "", "", ""]
  headers = ["Apply Sales Tax? (Y/N)", "ITEM ID", "15 CHARACTER DESCRIPTION", "", "100 CHARACTER DESCRIPTION", "", "1500 CHARACTER DESCRIPTION (OPTIONAL)", "", "FAIR MARKET VALUE", "ITEM STARTING BID", "MINIMUM BID INCREMENT", "GROUP ID", "CATEGORIES (OPTIONAL)", "", "BOA", "", ""]

  item = Mix.Tasks.ProcessAuctionItems.build_item(row, headers, skip_ai_processing: true)

  assert item.item_id == 103
  assert item.short_title == "Short"
  assert item.title == "Title"
  assert item.description == "Description"
end
```

Run:

```bash
mix test test/mix/tasks/process_auction_items_test.exs
```

**Commit message:** `Integrate description processing into Mix task`

---

### Step 7: Add processing cache to avoid redundant API calls

**Files to create:**

- `lib/receipts/processing_cache.ex`
- `test/receipts/processing_cache_test.exs`

**Files to modify:**

- `lib/receipts/description_processor.ex`
- `.gitignore`

**Changes:**

1. Create cache module:

```elixir
defmodule Receipts.ProcessingCache do
  @moduledoc """
  Caches AI processing results to avoid redundant API calls.
  Cache is keyed by description hash.
  """

  @cache_dir "db/auction_items/cache"

  def get(description) do
    cache_key = hash_description(description)
    cache_path = Path.join(@cache_dir, "#{cache_key}.json")

    case File.read(cache_path) do
      {:ok, content} -> Jason.decode(content)
      {:error, _} -> nil
    end
  end

  def put(description, result) do
    cache_key = hash_description(description)
    cache_path = Path.join(@cache_dir, "#{cache_key}.json")

    File.mkdir_p!(@cache_dir)
    File.write!(cache_path, Jason.encode!(result))
  end

  defp hash_description(description) do
    :crypto.hash(:sha256, description)
    |> Base.encode16(case: :lower)
  end
end
```

2. Update description processor to use cache:

```elixir
defp process_with_ai(attrs, description) do
  case ProcessingCache.get(description) do
    nil ->
      process_and_cache(attrs, description)

    cached_result ->
      Logger.info("Using cached result for item #{attrs[:item_id]}")
      apply_extraction(attrs, cached_result)
  end
end

defp process_and_cache(attrs, description) do
  case AnthropicClient.extract_fields(description) do
    {:ok, result} ->
      Logger.info("Successfully processed description for item #{attrs[:item_id]}")
      ProcessingCache.put(description, result)
      apply_extraction(attrs, result)

    {:error, reason} ->
      Logger.warning(
        "Failed to process description for item #{attrs[:item_id]}: #{inspect(reason)}"
      )
      attrs
  end
end

defp apply_extraction(attrs, %{expiration_notice: exp, notes: notes, description: clean_desc}) do
  attrs
  |> put_if_present(:expiration_notice, exp)
  |> put_if_present(:notes, notes)
  |> put_if_present(:description, clean_desc)
end
```

3. Create test file:

```elixir
defmodule Receipts.ProcessingCacheTest do
  use ExUnit.Case

  alias Receipts.ProcessingCache

  @cache_dir "db/auction_items/cache"

  setup do
    File.rm_rf!(@cache_dir)
    on_exit(fn -> File.rm_rf!(@cache_dir) end)
    :ok
  end

  describe "get/1 and put/2" do
    test "returns nil when cache entry doesn't exist" do
      assert ProcessingCache.get("test description") == nil
    end

    test "stores and retrieves cached results" do
      description = "Test auction item description"

      result = %{
        "expiration_notice" => "12/31/2026",
        "notes" => "Call ahead",
        "description" => "Clean description"
      }

      ProcessingCache.put(description, result)
      cached = ProcessingCache.get(description)

      assert cached == {:ok, result}
    end

    test "different descriptions have different cache keys" do
      ProcessingCache.put("description 1", %{"value" => "1"})
      ProcessingCache.put("description 2", %{"value" => "2"})

      assert ProcessingCache.get("description 1") == {:ok, %{"value" => "1"}}
      assert ProcessingCache.get("description 2") == {:ok, %{"value" => "2"}}
    end
  end
end
```

4. Update .gitignore to ignore cache directory:

```gitignore
# AI processing cache
db/auction_items/cache/
```

Run:

```bash
mix test test/receipts/processing_cache_test.exs
```

**Commit message:** `Add processing cache to avoid redundant API calls`

---

## Usage Instructions

After implementing this plan:

1. Create a `.env` file in the project root:

```bash
export ANTHROPIC_API_KEY=sk-ant-your-key-here
```

2. Load environment variables:

```bash
source .env
```

3. Run the task with AI processing (default):

```bash
mix process_auction_items
```

4. Run without AI processing:

```bash
mix process_auction_items --skip-ai-processing
```

## Testing Strategy

Each step includes unit tests. Integration testing:

1. Test with a small CSV file first
2. Verify cache is working (second run should be instant)
3. Check JSON output for proper field extraction
4. Verify graceful degradation when API is unavailable

## Cost Estimation

- Claude Haiku: ~$0.25 per million input tokens
- Average description: ~200 tokens
- Cost per item: ~$0.0001-0.0005
- For 100 items: ~$0.01-0.05
