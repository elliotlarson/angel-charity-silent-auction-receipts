# Implementation Plan: Add Text Normalization to Auction Item Descriptions

## Progress Checklist

- [ ] Step 1: Add normalize_text/1 function to AuctionItem module
- [ ] Step 2: Apply text normalization to description, title, and short_title fields

## Overview

This feature adds text normalization to the `Receipts.AuctionItem` module to clean up formatting issues in auction item data. The source CSV data contains various punctuation and spacing problems that make the output look unprofessional.

The normalization will handle:
- Spaces before punctuation (`.`, `,`, `!`, `?`, `;`, `:`)
- Missing spaces after sentence-ending punctuation (`.`, `!`, `?`)
- Multiple consecutive spaces collapsed to single space
- Applied to `description`, `title`, and `short_title` fields

## Key Design Decisions

**Single Normalization Function**: We'll create a private `normalize_text/1` function that handles all text cleaning. This keeps the logic centralized and reusable across all text fields.

**Regex-Based Approach**: Using Elixir's `Regex.replace/3` for each normalization rule allows us to chain transformations in a clear, maintainable way.

**Order of Operations**: The order matters - we'll:
1. Remove spaces before punctuation first
2. Then ensure spaces after sentence-ending punctuation
3. Finally collapse multiple spaces

This order prevents creating issues while fixing others (e.g., removing spaces before punctuation won't create double spaces that need cleanup).

**Nil Safety**: The function will handle nil values gracefully by returning empty strings, maintaining the existing behavior in `new/1`.

## Implementation Steps

### Step 1: Add normalize_text/1 function to AuctionItem module

**Files to modify:**
- `lib/receipts/auction_item.ex`
- `test/receipts/auction_item_test.exs`

**Changes:**

Add a private `normalize_text/1` function to the `Receipts.AuctionItem` module that performs the following transformations:

1. Remove spaces before punctuation marks (`.`, `,`, `!`, `?`, `;`, `:`)
2. Ensure single space after sentence-ending punctuation (`.`, `!`, `?`)
3. Collapse multiple consecutive spaces into a single space
4. Handle nil by returning empty string

Example implementation approach:

```elixir
defp normalize_text(nil), do: ""
defp normalize_text(text) when is_binary(text) do
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
```

Add comprehensive tests in `test/receipts/auction_item_test.exs` covering:

1. Spaces before periods, commas, exclamation marks, question marks, semicolons, colons
2. Missing spaces after sentence-ending punctuation
3. Multiple consecutive spaces
4. Combinations of multiple issues
5. Nil handling
6. Already clean text (no changes needed)

Example test cases:

```elixir
describe "normalize_text/1" do
  test "removes spaces before punctuation" do
    # Test the private function via the public new/1 interface
    attrs = %{
      item_id: "1",
      short_title: "artist ,",
      title: "services .",
      description: "This is cubism . Very nice !",
      fair_market_value: "100",
      categories: "ART"
    }

    item = AuctionItem.new(attrs)

    assert item.short_title == "artist,"
    assert item.title == "services."
    assert item.description == "This is cubism. Very nice!"
  end

  test "adds spaces after sentence-ending punctuation" do
    attrs = %{
      item_id: "1",
      short_title: "Test",
      title: "Title",
      description: "sentence.Another sentence!Third sentence?Fourth",
      fair_market_value: "100",
      categories: "TEST"
    }

    item = AuctionItem.new(attrs)

    assert item.description == "sentence. Another sentence! Third sentence? Fourth"
  end

  test "collapses multiple spaces" do
    attrs = %{
      item_id: "1",
      short_title: "This  is",
      title: "a   test",
      description: "with    multiple     spaces",
      fair_market_value: "100",
      categories: "TEST"
    }

    item = AuctionItem.new(attrs)

    assert item.short_title == "This is"
    assert item.title == "a test"
    assert item.description == "with multiple spaces"
  end

  test "handles combined issues" do
    attrs = %{
      item_id: "1",
      short_title: "Test",
      title: "Test",
      description: "This is a  rare item.Good for  collectors ; you!Lounge here .",
      fair_market_value: "100",
      categories: "TEST"
    }

    item = AuctionItem.new(attrs)

    assert item.description == "This is a rare item. Good for collectors; you! Lounge here."
  end
end
```

**Testing:**

Run the test suite:
```bash
mix test test/receipts/auction_item_test.exs
```

**Commit message:** `Add normalize_text/1 function to AuctionItem module`

---

### Step 2: Apply text normalization to description, title, and short_title fields

**Files to modify:**
- `lib/receipts/auction_item.ex`

**Changes:**

Update the `new/1` function to apply `normalize_text/1` to the `description`, `title`, and `short_title` fields:

```elixir
def new(attrs) do
  %__MODULE__{
    item_id: parse_integer(attrs[:item_id]),
    short_title: normalize_text(attrs[:short_title]),
    title: normalize_text(attrs[:title]),
    description: normalize_text(attrs[:description]),
    fair_market_value: parse_integer(attrs[:fair_market_value]),
    categories: attrs[:categories] || "",
    special_instructions: attrs[:special_instructions] || "",
    expiration_date: attrs[:expiration_date] || ""
  }
end
```

**Verification:**

The existing tests should all pass since:
- Tests with clean text will continue to work
- Tests with nil values will get empty strings as before
- The normalization tests from Step 1 verify the cleaning behavior

Run the full test suite:
```bash
mix test
```

**Additional Verification:**

To verify the normalization is working with real data, you can run the auction items processing task and inspect the JSON output:

```bash
mix process_auction_items
```

Check `db/auction_items/json/` files for cleaned text in description, title, and short_title fields.

**Commit message:** `Apply text normalization to description, title, and short_title fields`

---

## Session Resumability

The plan is structured so any Claude Code session can:
1. Check the progress checklist to see what's completed
2. Read the step details for the next unchecked item
3. Implement the step using the code examples as guidance
4. Update the checklist after committing

Each step is self-contained with full context for implementation.
