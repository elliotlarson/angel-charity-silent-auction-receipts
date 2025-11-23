defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  @external_resource "priv/templates/receipt.html.eex"
  @template File.read!("priv/templates/receipt.html.eex")

  @external_resource "priv/static/angel_charity_logo.svg"
  @logo_data_uri (fn ->
                    logo_content = File.read!("priv/static/angel_charity_logo.svg")
                    encoded = Base.encode64(logo_content)
                    "data:image/svg+xml;base64,#{encoded}"
                  end).()

  def generate_pdf(auction_item, output_path) do
    html = render_html(auction_item)
    ChromicPDF.print_to_pdf({:html, html}, output: output_path)
  end

  def save_html(auction_item, output_path) do
    html = render_html(auction_item)
    File.write(output_path, html)
  end

  def render_html(auction_item) do
    assigns = %{
      item: auction_item,
      formatted_value: Number.Currency.number_to_currency(auction_item.fair_market_value),
      logo_path: @logo_data_uri
    }

    EEx.eval_string(@template, assigns: assigns)
  end
end
