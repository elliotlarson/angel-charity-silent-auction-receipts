defmodule Receipts.TextNormalizerTest do
  use ExUnit.Case
  doctest Receipts.TextNormalizer

  alias Receipts.TextNormalizer

  describe "normalize/1" do
    test "removes spaces before periods" do
      assert TextNormalizer.normalize("services .") == "services."
      assert TextNormalizer.normalize("This is cubism .") == "This is cubism."
    end

    test "removes spaces before commas" do
      assert TextNormalizer.normalize("artist ,") == "artist,"
      assert TextNormalizer.normalize("red , blue , green") == "red, blue, green"
    end

    test "removes spaces before exclamation marks" do
      assert TextNormalizer.normalize("Very nice !") == "Very nice!"
      assert TextNormalizer.normalize("Welcome !") == "Welcome!"
    end

    test "removes spaces before question marks" do
      assert TextNormalizer.normalize("Is this art ?") == "Is this art?"
    end

    test "removes spaces before semicolons" do
      assert TextNormalizer.normalize("petting ; learning") == "petting; learning"
      assert TextNormalizer.normalize("Amber Levitz ; Lindsay") == "Amber Levitz; Lindsay"
    end

    test "removes spaces before colons" do
      assert TextNormalizer.normalize("Note : call ahead") == "Note: call ahead"
    end

    test "adds spaces after periods before capital letters" do
      assert TextNormalizer.normalize("sentence.Another") == "sentence. Another"
      assert TextNormalizer.normalize("finger.Good") == "finger. Good"
      assert TextNormalizer.normalize("Arizona.Certificate") == "Arizona. Certificate"
    end

    test "adds spaces after exclamation marks before capital letters" do
      assert TextNormalizer.normalize("you!Lounge") == "you! Lounge"
      assert TextNormalizer.normalize("Welcome!Please") == "Welcome! Please"
    end

    test "adds spaces after question marks before capital letters" do
      assert TextNormalizer.normalize("question?Answer") == "question? Answer"
    end

    test "collapses multiple consecutive spaces" do
      assert TextNormalizer.normalize("This  is") == "This is"
      assert TextNormalizer.normalize("a   test") == "a test"
      assert TextNormalizer.normalize("with    multiple     spaces") == "with multiple spaces"
      assert TextNormalizer.normalize("This is a  rare") == "This is a rare"
      assert TextNormalizer.normalize("vision of  Jack") == "vision of Jack"
    end

    test "handles combined issues" do
      input = "This is a  rare item.Good for  collectors ; you!Lounge here ."
      expected = "This is a rare item. Good for collectors; you! Lounge here."
      assert TextNormalizer.normalize(input) == expected
    end

    test "handles multiple sentence-ending punctuation marks" do
      input = "sentence.Another sentence!Third sentence?Fourth"
      expected = "sentence. Another sentence! Third sentence? Fourth"
      assert TextNormalizer.normalize(input) == expected
    end

    test "handles nil by returning empty string" do
      assert TextNormalizer.normalize(nil) == ""
    end

    test "handles empty string" do
      assert TextNormalizer.normalize("") == ""
    end

    test "handles already clean text" do
      clean_text = "This is already clean. No issues here!"
      assert TextNormalizer.normalize(clean_text) == clean_text
    end

    test "preserves lowercase letters after punctuation" do
      assert TextNormalizer.normalize("e.g.") == "e.g."
      assert TextNormalizer.normalize("i.e.") == "i.e."
    end

    test "adds space after period before capital letter even in abbreviations" do
      assert TextNormalizer.normalize("Dr.Smith") == "Dr. Smith"
      assert TextNormalizer.normalize("Mr.Jones") == "Mr. Jones"
    end

    test "adds space after closing paren when followed by letter or number" do
      assert TextNormalizer.normalize("(707)204-0037") == "(707) 204-0037"
      assert TextNormalizer.normalize("text)more") == "text) more"
      assert TextNormalizer.normalize("(item)A") == "(item) A"
    end

    test "does not add space after closing paren when followed by punctuation" do
      assert TextNormalizer.normalize("text).") == "text)."
      assert TextNormalizer.normalize("(item),") == "(item),"
    end

    test "formats phone numbers to standard format" do
      assert TextNormalizer.normalize("336-601-6348") == "(336) 601-6348"
      assert TextNormalizer.normalize("520-838-2571") == "(520) 838-2571"

      assert TextNormalizer.normalize("Call 520-577-4061 for info") ==
               "Call (520) 577-4061 for info"
    end

    test "formats multiple phone numbers in text" do
      input = "Call 520-297-3322 or 520-825-3048"
      expected = "Call (520) 297-3322 or (520) 825-3048"
      assert TextNormalizer.normalize(input) == expected
    end

    test "preserves already formatted phone numbers" do
      assert TextNormalizer.normalize("(336) 601-6348") == "(336) 601-6348"
    end
  end
end
