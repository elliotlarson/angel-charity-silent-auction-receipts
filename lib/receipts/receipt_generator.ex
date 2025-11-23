defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  alias Receipts.Config

  def generate_pdf(auction_item, output_path) do
    html = render_html(auction_item)
    ChromicPDF.print_to_pdf({:html, html}, output: output_path)
  end

  def save_html(auction_item, output_path) do
    html = render_html(auction_item)
    File.write(output_path, html)
  end

  def render_html(auction_item) do
    template = File.read!(Config.template_path())

    assigns = %{
      item: auction_item,
      formatted_value: Number.Currency.number_to_currency(auction_item.fair_market_value),
      logo_path: get_logo_data_uri()
    }

    EEx.eval_string(template, assigns: assigns)
  end

  defp get_logo_data_uri do
    logo_content = File.read!(Config.logo_path())
    encoded = Base.encode64(logo_content)
    "data:image/svg+xml;base64,#{encoded}"
  end
end
