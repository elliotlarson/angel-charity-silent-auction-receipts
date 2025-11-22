defmodule Receipts.HtmlFormatterTest do
  use ExUnit.Case
  alias Receipts.HtmlFormatter

  describe "format_description/1" do
    test "converts double newlines to paragraphs" do
      input = "First paragraph\n\nSecond paragraph"
      expected = "<p>First paragraph</p>\n<p>Second paragraph</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles single newlines within text" do
      input = "Line 1\nLine 2"
      expected = "<p>Line 1<br>\nLine 2</p>"
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
      expected = "<p>First</p>\n<p>Second</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles multiple consecutive newlines as paragraph break" do
      input = "Para 1\n\n\n\nPara 2"
      expected = "<p>Para 1</p>\n<p>Para 2</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "formats real Portuguese wine example from CSV" do
      input = """
      Win a a perfect trip to discover some Portuguese wine regions, while also enjoying the comfort of staying at two Portugal manor house estates. This one-week trip combines the discovery of the landscape and cultural jewels of the historic Minho and the UNESCO-protected Douro Valley with the enjoyment of high-quality wines and instructive insights into the production methods. Your accommodations are two internationally renowned wineries in the &ldquo;Solares de Portugal.&rdquo; Viana do Castelo and Lamego, Portugal

      INCLUDES:
      - 7 nights accommodation
      - 4 nights at Quinta do Ameal, Viana do Castelo and 3 nights at Casa de Santo Ant&oacute;nio de Britiande, Lamego
      - Welcome-Drink at each property

      - 2 Cooking classes
      - 2 Wine tastings
      - Breakfast included daily
      - 2 Dinners (excluding drinks)

      - Valid year-round; weekday check-ins only

      Travelers are responsible for all transportation, including airport transfers and transportation between cities.

      NOT INCLUDED: flights, meals ; beverages not mentioned, rental car, fuel, tolls, guides, entrance fees to archeological sites, museums, and wineries outside the properties where you are staying, personal expenses, private or guided tours

      Subject to availability. Not valid during Thanksgiving, Christmas ; USA holidays.
      """
      |> String.trim()

      expected = """
      <p>Win a a perfect trip to discover some Portuguese wine regions, while also enjoying the comfort of staying at two Portugal manor house estates. This one-week trip combines the discovery of the landscape and cultural jewels of the historic Minho and the UNESCO-protected Douro Valley with the enjoyment of high-quality wines and instructive insights into the production methods. Your accommodations are two internationally renowned wineries in the &ldquo;Solares de Portugal.&rdquo; Viana do Castelo and Lamego, Portugal</p>
      <p>INCLUDES:<br>
      - 7 nights accommodation<br>
      - 4 nights at Quinta do Ameal, Viana do Castelo and 3 nights at Casa de Santo Ant&oacute;nio de Britiande, Lamego<br>
      - Welcome-Drink at each property</p>
      <p>- 2 Cooking classes<br>
      - 2 Wine tastings<br>
      - Breakfast included daily<br>
      - 2 Dinners (excluding drinks)</p>
      <p>- Valid year-round; weekday check-ins only</p>
      <p>Travelers are responsible for all transportation, including airport transfers and transportation between cities.</p>
      <p>NOT INCLUDED: flights, meals ; beverages not mentioned, rental car, fuel, tolls, guides, entrance fees to archeological sites, museums, and wineries outside the properties where you are staying, personal expenses, private or guided tours</p>
      <p>Subject to availability. Not valid during Thanksgiving, Christmas ; USA holidays.</p>
      """
      |> String.trim()

      assert HtmlFormatter.format_description(input) == expected
    end
  end
end
