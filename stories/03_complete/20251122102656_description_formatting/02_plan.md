# Implementation Plan: Description Formatting

## Progress Checklist

- [x] Step 1: Convert newlines to HTML in description field
- [x] Step 2: Add HTML formatting for bullet points

## Overview

The CSV source data contains formatted text with newlines and bullet points, but this formatting is being lost during JSON conversion. The text appears as a single blob without any visual structure.

For example, this formatted text in the CSV:
```
Portugal\n\nINCLUDES:\n- 7 nights accommodation\n- 4 nights at Quinta...\n\n- Valid year-round
```

Currently becomes:
```
PortugalINCLUDES:- 7 nights accommodation- 4 nights at Quinta...- Valid year-round
```

We need to convert the plain text formatting to HTML to preserve the structure when displayed.

## Key Design Decisions

**HTML Instead of Plain Text**: The story asks "can we maintain the plain text formatting?" but plain text formatting (newlines) doesn't render in HTML contexts. Since these descriptions will likely be displayed on a web page, converting to HTML is the practical solution.

**Following Phoenix.HTML.Format Patterns**: We'll follow the battle-tested approach from Phoenix's `text_to_html` function (from phoenix_html_helpers), which handles paragraph/line break conversion. We'll extend it with bullet list support.

**Conversion Strategy**:
1. `\n\n` or `\r\n\r\n` (double newlines) become `<p>` tags for paragraphs
2. `\n` or `\r\n` (single newlines) become `<br>` tags for line breaks
3. Lines starting with `- ` become `<li>` items in `<ul>` lists
4. Empty/whitespace-only paragraphs are filtered out using Phoenix's `not_blank?` pattern

**Processing Order**: We'll handle formatting conversion AFTER the existing TextNormalizer runs, so we can leverage the existing cleanup logic.

**New Module vs Extending TextNormalizer**: Create a separate `Receipts.HtmlFormatter` module to keep concerns separated. TextNormalizer handles spacing/punctuation, HtmlFormatter handles structure.

**Only Description Field**: Based on the story examples, only the `description` field (1500 character field) has this multi-line formatting. The `short_title` and `title` fields remain plain text.

**No HTML Escaping**: Unlike Phoenix's version, we won't escape HTML entities because the CSV already contains valid HTML entities like `&ldquo;` and `&oacute;` that should be preserved.

## Implementation Steps

### Step 1: Convert newlines to HTML in description field

**Files to create:**
- `lib/receipts/html_formatter.ex`
- `test/receipts/html_formatter_test.exs`

**Files to modify:**
- `lib/receipts/auction_item.ex`

**Changes:**

Create `lib/receipts/html_formatter.ex` following Phoenix.HTML.Format patterns:

```elixir
defmodule Receipts.HtmlFormatter do
  @moduledoc """
  Converts plain text formatting to HTML for auction item descriptions.

  Inspired by Phoenix.HTML.Format.text_to_html but extended with bullet list support.
  """

  def format_description(nil), do: ""
  def format_description(""), do: ""

  def format_description(text) when is_binary(text) do
    text
    |> String.split(["\n\n", "\r\n\r\n"], trim: true)
    |> Enum.filter(&not_blank?/1)
    |> Enum.map(&wrap_paragraph/1)
    |> Enum.join("\n")
  end

  defp not_blank?("\r\n" <> rest), do: not_blank?(rest)
  defp not_blank?("\n" <> rest), do: not_blank?(rest)
  defp not_blank?(" " <> rest), do: not_blank?(rest)
  defp not_blank?(""), do: false
  defp not_blank?(_), do: true

  defp wrap_paragraph(text) do
    content = insert_line_breaks(text)
    "<p>#{content}</p>"
  end

  defp insert_line_breaks(text) do
    text
    |> String.split(["\n", "\r\n"], trim: true)
    |> Enum.join("<br>\n")
  end
end
```

Update `lib/receipts/auction_item.ex` to apply HTML formatting to the description field:

```elixir
defmodule Receipts.AuctionItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

  # ... existing code ...

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

Create comprehensive tests in `test/receipts/html_formatter_test.exs`:

```elixir
defmodule Receipts.HtmlFormatterTest do
  use ExUnit.Case
  alias Receipts.HtmlFormatter

  describe "format_description/1" do
    test "converts double newlines to paragraphs" do
      input = "First paragraph\n\nSecond paragraph"
      expected = "<p>First paragraph</p><p>Second paragraph</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles single newlines within text" do
      input = "Line 1\nLine 2"
      expected = "<p>Line 1<br>Line 2</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles nil by returning empty string" do
      assert HtmlFormatter.format_description(nil) == ""
    end

    test "handles empty string" do
      assert HtmlFormatter.format_description("") == ""
    end

    test "trims whitespace from paragraphs" do
      input = "  First  \n\n  Second  "
      expected = "<p>First</p><p>Second</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles multiple consecutive newlines as paragraph break" do
      input = "Para 1\n\n\n\nPara 2"
      expected = "<p>Para 1</p><p>Para 2</p>"
      assert HtmlFormatter.format_description(input) == expected
    end
  end
end
```

**Testing:**

Run tests:
```bash
mix test test/receipts/html_formatter_test.exs
mix test test/receipts/auction_item_test.exs
```

**Commit message:** `Convert newlines to HTML in description field`

---

### Step 2: Add HTML formatting for bullet points

**Files to modify:**
- `lib/receipts/html_formatter.ex`
- `test/receipts/html_formatter_test.exs`

**Changes:**

Update `lib/receipts/html_formatter.ex` to detect and format bullet lists while keeping Phoenix patterns:

```elixir
defmodule Receipts.HtmlFormatter do
  @moduledoc """
  Converts plain text formatting to HTML for auction item descriptions.

  Inspired by Phoenix.HTML.Format.text_to_html but extended with bullet list support.
  """

  def format_description(nil), do: ""
  def format_description(""), do: ""

  def format_description(text) when is_binary(text) do
    text
    |> String.split(["\n\n", "\r\n\r\n"], trim: true)
    |> Enum.filter(&not_blank?/1)
    |> Enum.map(&format_block/1)
    |> Enum.join("\n")
  end

  defp not_blank?("\r\n" <> rest), do: not_blank?(rest)
  defp not_blank?("\n" <> rest), do: not_blank?(rest)
  defp not_blank?(" " <> rest), do: not_blank?(rest)
  defp not_blank?(""), do: false
  defp not_blank?(_), do: true

  defp format_block(block) do
    if is_bullet_list?(block) do
      format_bullet_list(block)
    else
      wrap_paragraph(block)
    end
  end

  defp is_bullet_list?(block) do
    block
    |> String.split(["\n", "\r\n"], trim: true)
    |> Enum.any?(&String.starts_with?(&1, "- "))
  end

  defp format_bullet_list(block) do
    items =
      block
      |> String.split(["\n", "\r\n"], trim: true)
      |> Enum.map(&format_list_item/1)
      |> Enum.join("\n")

    "<ul>\n#{items}\n</ul>"
  end

  defp format_list_item(line) do
    if String.starts_with?(line, "- ") do
      content = String.slice(line, 2..-1//1)
      "<li>#{content}</li>"
    else
      "<li>#{line}</li>"
    end
  end

  defp wrap_paragraph(text) do
    content = insert_line_breaks(text)
    "<p>#{content}</p>"
  end

  defp insert_line_breaks(text) do
    text
    |> String.split(["\n", "\r\n"], trim: true)
    |> Enum.join("<br>\n")
  end
end
```

Update tests in `test/receipts/html_formatter_test.exs`:

```elixir
defmodule Receipts.HtmlFormatterTest do
  use ExUnit.Case
  alias Receipts.HtmlFormatter

  describe "format_description/1" do
    test "converts double newlines to paragraphs" do
      input = "First paragraph\n\nSecond paragraph"
      expected = "<p>First paragraph</p><p>Second paragraph</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "converts single newlines to br tags within paragraphs" do
      input = "Line 1\nLine 2\nLine 3"
      expected = "<p>Line 1<br>Line 2<br>Line 3</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "converts bullet lists to ul/li tags" do
      input = "- Item 1\n- Item 2\n- Item 3"
      expected = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles bullet list with header line" do
      input = "INCLUDES:\n- Item 1\n- Item 2"
      expected = "<ul><li>INCLUDES:</li><li>Item 1</li><li>Item 2</li></ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles mixed content with paragraphs and lists" do
      input = "Intro text\n\n- Item 1\n- Item 2\n\nClosing text"
      expected = "<p>Intro text</p><ul><li>Item 1</li><li>Item 2</li></ul><p>Closing text</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles complex example from CSV" do
      input = """
      This is a trip to Portugal.

      INCLUDES:
      - 7 nights accommodation
      - Breakfast included daily

      NOT INCLUDED: flights, meals
      """
      |> String.trim()

      result = HtmlFormatter.format_description(input)
      assert result =~ "<p>This is a trip to Portugal.</p>"
      assert result =~ "<ul>"
      assert result =~ "<li>INCLUDES:</li>"
      assert result =~ "<li>7 nights accommodation</li>"
      assert result =~ "<li>Breakfast included daily</li>"
      assert result =~ "</ul>"
      assert result =~ "<p>NOT INCLUDED: flights, meals</p>"
    end

    test "handles nil by returning empty string" do
      assert HtmlFormatter.format_description(nil) == ""
    end

    test "handles empty string" do
      assert HtmlFormatter.format_description("") == ""
    end

    test "trims whitespace from blocks" do
      input = "  First  \n\n  - Item  "
      result = HtmlFormatter.format_description(input)
      assert result =~ "<p>First</p>"
      assert result =~ "<li>Item</li>"
    end
  end
end
```

**Testing:**

Run tests:
```bash
mix test test/receipts/html_formatter_test.exs
mix test
```

Manually test with real data:
```bash
echo "1" | mix process_auction_items
jq '.[] | select(.item_id == 125) | .description' db/auction_items/json/20251121_auction_items.json
```

Verify the output contains `<p>`, `<ul>`, `<li>`, and `<br>` tags.

**Commit message:** `Add HTML formatting for bullet points`

---

## Notes

**Phoenix.HTML.Format Inspiration**: The implementation follows patterns from Phoenix's `text_to_html` function (see [phoenix_html_helpers/lib/phoenix_html_helpers/format.ex](https://github.com/phoenixframework/phoenix_html_helpers/blob/main/lib/phoenix_html_helpers/format.ex)):
- Uses `trim: true` when splitting to avoid empty strings
- Implements `not_blank?/1` recursively to filter whitespace-only blocks
- Handles both Unix (`\n`) and Windows (`\r\n`) line endings
- Joins output with newlines for readable HTML

**Whitespace Handling**: The Phoenix patterns automatically handle trailing spaces and empty lines:
- `trim: true` removes leading/trailing empty strings when splitting
- `not_blank?/1` recursively strips whitespace and newlines to detect empty blocks
- No additional whitespace normalization needed

**TextNormalizer Interaction**: The TextNormalizer runs BEFORE HtmlFormatter in the changeset pipeline. This means:
- Spacing and punctuation cleanup happens on the raw text
- HTML formatting happens on the cleaned text
- This order is important to avoid the normalizer breaking HTML tags

**HTML Entity Handling**: The CSV contains HTML entities like `&ldquo;` and `&oacute;`. These are passed through unchanged (no escaping), which is correct behavior. They'll render properly when the HTML is displayed.

**Edge Cases Handled**:
- Empty lines between bullet points - filtered by `not_blank?/1`
- Trailing spaces on lines - removed by `trim: true`
- Lines with only whitespace - filtered by `not_blank?/1`
- Windows vs Unix line endings - handled by splitting on both `\r\n` and `\n`

**Alternative Approaches Considered**:
1. Using `phoenix_html` dependency - rejected to keep dependencies minimal for a non-web project
2. Converting to Markdown instead of HTML - rejected because the output is JSON for web display
3. Detecting list headers (INCLUDES:, NOT INCLUDED:) specially - rejected for simplicity, they work fine as list items
4. Preserving literal `\n` characters in JSON - rejected because they won't render in HTML contexts
