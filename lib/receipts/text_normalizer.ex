defmodule Receipts.TextNormalizer do
  @moduledoc """
  Provides text normalization functions for cleaning up formatting issues
  in text data, such as spacing around punctuation.
  """

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
    Regex.replace(~r/\s+([.,!?;:])/, text, "\\1")
  end

  defp add_spaces_after_sentence_punctuation(text) do
    Regex.replace(~r/([.!?])([A-Z])/, text, "\\1 \\2")
  end

  defp add_spaces_after_parens(text) do
    Regex.replace(~r/\)([A-Za-z0-9])/, text, ") \\1")
  end

  defp collapse_multiple_spaces(text) do
    Regex.replace(~r/ {2,}/, text, " ")
  end

  defp format_phone_numbers(text) do
    Regex.replace(~r/(\d{3})-(\d{3})-(\d{4})/, text, "(\\1) \\2-\\3")
  end
end
