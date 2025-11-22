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
    |> Enum.map(&String.trim/1)
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
