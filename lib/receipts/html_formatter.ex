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
    |> Enum.any?(&String.match?(&1, ~r/^\s*-/))
  end

  defp format_bullet_list(block) do
    lines =
      block
      |> String.split(["\n", "\r\n"], trim: true)

    {headers, list_items} = split_headers_and_items(lines)

    header_html =
      if headers != [] do
        headers
        |> Enum.map(&"<h5>#{String.trim(&1)}</h5>")
        |> Enum.join("\n")
      else
        ""
      end

    items_html =
      list_items
      |> Enum.map(&format_list_item/1)
      |> Enum.join("\n")

    list_html = "<ul>\n#{items_html}\n</ul>"

    if header_html != "" do
      "#{header_html}\n#{list_html}"
    else
      list_html
    end
  end

  defp split_headers_and_items(lines) do
    Enum.split_while(lines, fn line ->
      trimmed = String.trim(line)
      String.ends_with?(trimmed, ":") and not String.match?(line, ~r/^\s*-/)
    end)
  end

  defp format_list_item(line) do
    if String.match?(line, ~r/^\s*-/) do
      content = String.replace(line, ~r/^\s*-\s*/, "")
      "<li>#{content}</li>"
    else
      trimmed = String.trim(line)
      "<li>#{trimmed}</li>"
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
