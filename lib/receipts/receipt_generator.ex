defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  @template_path "priv/templates/receipt.html.eex"
  @logo_path "priv/static/angel_charity_logo.svg"

  def generate_pdf(auction_item, output_path) do
    html = render_html(auction_item)
    ChromicPDF.print_to_pdf({:html, html}, output: output_path)
  end

  def render_html(auction_item) do
    template = File.read!(@template_path)

    assigns = %{
      item: auction_item,
      formatted_value: format_currency(auction_item.fair_market_value),
      logo_path: get_logo_data_uri()
    }

    EEx.eval_string(template, assigns: assigns)
  end

  defp format_currency(value) when is_integer(value) do
    dollars = div(value, 1)
    cents = 0

    whole_part =
      dollars
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    "$#{whole_part}.#{String.pad_leading(Integer.to_string(cents), 2, "0")}"
  end

  defp get_logo_data_uri do
    logo_content = File.read!(@logo_path)
    encoded = Base.encode64(logo_content)
    "data:image/svg+xml;base64,#{encoded}"
  end
end
