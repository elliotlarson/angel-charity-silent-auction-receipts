# Implementation Plan: Add Text Normalization to Auction Item Descriptions

## Progress Checklist

- [x] Step 1: Create TextNormalizer module for text cleaning
- [x] Step 2: Refactor AuctionItem to use Ecto embedded schema and changesets

## Overview

This feature adds text normalization to the `Receipts.AuctionItem` module to clean up formatting issues in auction item data. The source CSV data contains various punctuation and spacing problems that make the output look unprofessional.

The normalization will handle:
- Spaces before punctuation (`.`, `,`, `!`, `?`, `;`, `:`)
- Missing spaces after sentence-ending punctuation (`.`, `!`, `?`)
- Multiple consecutive spaces collapsed to single space
- Applied to `description`, `title`, and `short_title` fields

Additionally, we'll refactor `AuctionItem` to use Ecto changesets for more idiomatic data processing.

## Key Design Decisions

**Separate TextNormalizer Module**: Instead of keeping normalization logic in AuctionItem, we'll create a dedicated `Receipts.TextNormalizer` module. This provides:
- Better separation of concerns
- Reusability across other modules
- Easier testing in isolation
- Cleaner AuctionItem code

**Regex-Based Approach**: Using Elixir's `Regex.replace/3` for each normalization rule allows us to chain transformations in a clear, maintainable way.

**Order of Operations**: The order matters - we'll:
1. Remove spaces before punctuation first
2. Then ensure spaces after sentence-ending punctuation
3. Finally collapse multiple spaces

This order prevents creating issues while fixing others (e.g., removing spaces before punctuation won't create double spaces that need cleanup).

**Nil Safety**: The normalization function will handle nil values gracefully by returning empty strings.

**Ecto Changesets**: We'll refactor AuctionItem to use Ecto's embedded schema pattern for more idiomatic Elixir data processing. This provides:
- Automatic type casting (string to integer)
- Validation with error collection
- Standard pattern familiar to Elixir developers
- Clear schema definition
- Better error handling instead of silent defaults

## Implementation Steps

### Step 1: Create TextNormalizer module for text cleaning

**Files to create:**
- `lib/receipts/text_normalizer.ex`
- `test/receipts/text_normalizer_test.exs`

**Files to modify:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

Create a new `Receipts.TextNormalizer` module that performs the following transformations:

1. Remove spaces before punctuation marks (`.`, `,`, `!`, `?`, `;`, `:`)
2. Ensure single space after sentence-ending punctuation (`.`, `!`, `?`)
3. Collapse multiple consecutive spaces into a single space
4. Handle nil by returning empty string

Create `lib/receipts/text_normalizer.ex`:

```elixir
defmodule Receipts.TextNormalizer do
  @moduledoc """
  Provides text normalization functions for cleaning up formatting issues
  in text data, such as spacing around punctuation.
  """

  def normalize(nil), do: ""
  def normalize(text) when is_binary(text) do
    text
    |> remove_spaces_before_punctuation()
    |> add_spaces_after_sentence_punctuation()
    |> collapse_multiple_spaces()
  end

  defp remove_spaces_before_punctuation(text) do
    Regex.replace(~r/\s+([.,!?;:])/, text, "\\1")
  end

  defp add_spaces_after_sentence_punctuation(text) do
    Regex.replace(~r/([.!?])([A-Z])/, text, "\\1 \\2")
  end

  defp collapse_multiple_spaces(text) do
    Regex.replace(~r/\s{2,}/, text, " ")
  end
end
```

Update `lib/receipts/auction_item.ex` to use the TextNormalizer:

```elixir
defmodule Receipts.AuctionItem do
  alias Receipts.TextNormalizer

  # ... existing code ...

  def new(attrs) do
    %__MODULE__{
      item_id: parse_integer(attrs[:item_id]),
      short_title: TextNormalizer.normalize(attrs[:short_title]),
      title: TextNormalizer.normalize(attrs[:title]),
      description: TextNormalizer.normalize(attrs[:description]),
      fair_market_value: parse_integer(attrs[:fair_market_value]),
      categories: attrs[:categories] || "",
      special_instructions: attrs[:special_instructions] || "",
      expiration_date: attrs[:expiration_date] || ""
    }
  end
end
```

Add comprehensive tests in `test/receipts/text_normalizer_test.exs` covering:

1. Spaces before periods, commas, exclamation marks, question marks, semicolons, colons
2. Missing spaces after sentence-ending punctuation
3. Multiple consecutive spaces
4. Combinations of multiple issues
5. Nil handling
6. Empty strings
7. Already clean text (no changes needed)

Also add integration tests in `test/receipts/auction_item_test.exs` to verify normalization works through the AuctionItem.new/1 interface.

**Testing:**

Run the test suite:
```bash
mix test
```

All tests should pass (26 TextNormalizer tests + 12 AuctionItem tests).

**Commit message:** `Add text normalization to auction item descriptions`

---

### Step 2: Refactor AuctionItem to use Ecto embedded schema and changesets

**Files to modify:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`
- `mix.exs` (if Ecto not already a dependency)

**Changes:**

1. Check if Ecto is already a dependency. If not, add it to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:ecto, "~> 3.11"}
  ]
end
```

2. Refactor `lib/receipts/auction_item.ex` to use Ecto embedded schema:

```elixir
defmodule Receipts.AuctionItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :item_id, :integer
    field :short_title, :string
    field :title, :string
    field :description, :string
    field :fair_market_value, :integer
    field :categories, :string
    field :special_instructions, :string
    field :expiration_date, :string
  end

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

  def new(attrs) do
    attrs
    |> changeset()
    |> apply_action!(:insert)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :item_id,
      :short_title,
      :title,
      :description,
      :fair_market_value,
      :categories,
      :special_instructions,
      :expiration_date
    ])
    |> validate_required([:item_id, :short_title, :title, :description, :fair_market_value, :categories])
    |> normalize_text_fields()
    |> apply_defaults()
  end

  defp normalize_text_fields(changeset) do
    changeset
    |> update_change(:short_title, &TextNormalizer.normalize/1)
    |> update_change(:title, &TextNormalizer.normalize/1)
    |> update_change(:description, &TextNormalizer.normalize/1)
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default(:categories, "")
    |> put_default(:special_instructions, "")
    |> put_default(:expiration_date, "")
  end

  defp put_default(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      _ -> changeset
    end
  end
end
```

3. Update tests to handle the new changeset-based approach:
   - Ecto will automatically cast string integers to integers
   - Empty strings "" for numeric fields will now raise errors instead of defaulting to 0
   - Need to update tests that expect silent error handling

**Testing:**

Run the test suite and update any failing tests:
```bash
mix test
```

Expected changes:
- Tests with empty string numeric fields may need adjustment
- Ecto provides better error messages for invalid data
- Type casting is now automatic and explicit

**Verification:**

Verify the normalization still works with real data:
```bash
mix process_auction_items
```

Check `db/auction_items/json/` files for cleaned text and proper integer conversion.

**Commit message:** `Refactor AuctionItem to use Ecto embedded schema and changesets`

---

## Session Resumability

The plan is structured so any Claude Code session can:
1. Check the progress checklist to see what's completed
2. Read the step details for the next unchecked item
3. Implement the step using the code examples as guidance
4. Update the checklist after committing

Each step is self-contained with full context for implementation.
