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

    test "converts bullet lists to ul/li tags" do
      input = "- Item 1\n- Item 2\n- Item 3"
      expected = "<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles bullet list with header line" do
      input = "INCLUDES:\n- Item 1\n- Item 2"
      expected = "<h5>INCLUDES:</h5>\n<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n</ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles mixed content with paragraphs and lists" do
      input = "Intro text\n\n- Item 1\n- Item 2\n\nClosing text"
      expected = "<p>Intro text</p>\n<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n</ul>\n<p>Closing text</p>"
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
      <h5>INCLUDES:</h5>
      <ul>
      <li>7 nights accommodation</li>
      <li>4 nights at Quinta do Ameal, Viana do Castelo and 3 nights at Casa de Santo Ant&oacute;nio de Britiande, Lamego</li>
      <li>Welcome-Drink at each property</li>
      </ul>
      <ul>
      <li>2 Cooking classes</li>
      <li>2 Wine tastings</li>
      <li>Breakfast included daily</li>
      <li>2 Dinners (excluding drinks)</li>
      </ul>
      <ul>
      <li>Valid year-round; weekday check-ins only</li>
      </ul>
      <p>Travelers are responsible for all transportation, including airport transfers and transportation between cities.</p>
      <p>NOT INCLUDED: flights, meals ; beverages not mentioned, rental car, fuel, tolls, guides, entrance fees to archeological sites, museums, and wineries outside the properties where you are staying, personal expenses, private or guided tours</p>
      <p>Subject to availability. Not valid during Thanksgiving, Christmas ; USA holidays.</p>
      """
      |> String.trim()

      assert HtmlFormatter.format_description(input) == expected
    end

    test "trims whitespace from blocks" do
      input = "  First  \n\n  - Item  "
      result = HtmlFormatter.format_description(input)
      assert result =~ "<p>First</p>"
      assert result =~ "<li>Item</li>"
    end

    test "handles bullet lists with leading spaces" do
      input = "INCLUDES:\n - Item 1\n - Item 2\n  - Item 3"
      expected = "<h5>INCLUDES:</h5>\n<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "handles bullet lists with tabs" do
      input = "INCLUDES:\n\t- Item 1\n\t- Item 2"
      expected = "<h5>INCLUDES:</h5>\n<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n</ul>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "converts http URLs to links" do
      input = "Visit http://example.com for more info"
      expected = "<p>Visit <a href=\"http://example.com\">http://example.com</a> for more info</p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "converts https URLs to links" do
      input = "Redeem at https://redeem.travelpledge.com/T42825"
      expected = "<p>Redeem at <a href=\"https://redeem.travelpledge.com/T42825\">https://redeem.travelpledge.com/T42825</a></p>"
      assert HtmlFormatter.format_description(input) == expected
    end

    test "converts multiple URLs to links" do
      input = "Visit https://example.com or http://another.com"
      result = HtmlFormatter.format_description(input)
      assert result =~ "<a href=\"https://example.com\">https://example.com</a>"
      assert result =~ "<a href=\"http://another.com\">http://another.com</a>"
    end

    test "converts URLs in bullet lists" do
      input = "Resources:\n- https://example.com\n- http://test.org"
      result = HtmlFormatter.format_description(input)
      assert result =~ "<a href=\"https://example.com\">https://example.com</a>"
      assert result =~ "<a href=\"http://test.org\">http://test.org</a>"
    end
  end
end
