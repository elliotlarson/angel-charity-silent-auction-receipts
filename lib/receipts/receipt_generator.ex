defmodule Receipts.ReceiptGenerator do
  @moduledoc """
  Generates PDF receipts for auction items using ChromicPDF.
  """

  @external_resource "priv/templates/receipt.html.eex"
  @template File.read!("priv/templates/receipt.html.eex")

  @external_resource "priv/templates/receipt_footer.html.eex"
  @footer_template File.read!("priv/templates/receipt_footer.html.eex")

  @external_resource "priv/static/angel_charity_logo.svg"
  @logo_data_uri (fn ->
                    logo_content = File.read!("priv/static/angel_charity_logo.svg")
                    encoded = Base.encode64(logo_content)
                    "data:image/svg+xml;base64,#{encoded}"
                  end).()

  def generate_pdf(line_item, output_path) do
    import Ecto.Query
    alias Receipts.Repo
    alias Receipts.LineItem

    # Preload item for display
    line_item =
      if Ecto.assoc_loaded?(line_item.item) do
        line_item
      else
        Repo.preload(line_item, :item)
      end

    html = render_html(line_item)
    item_number = line_item.item.item_identifier

    # Get line item count for this item
    line_item_count =
      if line_item.item_id do
        from(li in LineItem, where: li.item_id == ^line_item.item_id)
        |> Repo.aggregate(:count, :id)
      else
        1
      end

    # Build footer text with line item identifier if multiple line items
    item_label = if line_item_count > 1 do
      "Item ##{item_number} (#{line_item.identifier})"
    else
      "Item ##{item_number}"
    end

    # Render footer template with item label
    footer_html = EEx.eval_string(@footer_template, assigns: %{item_label: item_label})

    ChromicPDF.print_to_pdf(
      {:html, html},
      output: output_path,
      print_to_pdf: %{
        displayHeaderFooter: true,
        headerTemplate: "<span></span>",
        footerTemplate: footer_html,
        marginBottom: 0.6
      }
    )
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
