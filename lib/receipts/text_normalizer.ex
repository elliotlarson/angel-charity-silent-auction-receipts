defmodule Receipts.TextNormalizer do
  @moduledoc """
  Provides text normalization functions for cleaning up formatting issues
  in text data, such as spacing around punctuation.
  """

  @doc """
  Normalizes text by:
  - Removing spaces before punctuation (., , ! ? ; :)
  - Adding spaces after sentence-ending punctuation (. ! ?)
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
