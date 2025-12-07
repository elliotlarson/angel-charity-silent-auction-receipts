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

  def render_html(line_item) do
    import Ecto.Query
    alias Receipts.Repo
    alias Receipts.LineItem

    # Preload the item association if not already loaded
    line_item =
      if Ecto.assoc_loaded?(line_item.item) do
        line_item
      else
        Repo.preload(line_item, :item)
      end

    # Get total count and position for this line item (if item_id is set)
    {current_position, total_count} =
      if line_item.item_id do
        line_items_for_item =
          from(li in LineItem,
            where: li.item_id == ^line_item.item_id,
            order_by: [asc: li.identifier],
            select: li.identifier
          )
          |> Repo.all()

        total = length(line_items_for_item)
        position = Enum.find_index(line_items_for_item, &(&1 == line_item.identifier)) + 1
        {position, total}
      else
        # For test structs without item_id, assume single line item
        {1, 1}
      end

    assigns = %{
      line_item: line_item,
      item: line_item,
      formatted_value: Number.Currency.number_to_currency(line_item.value),
      logo_path: @logo_data_uri,
      line_item_position: current_position,
      line_item_total: total_count
    }

    EEx.eval_string(@template, assigns: assigns)
  end
end
