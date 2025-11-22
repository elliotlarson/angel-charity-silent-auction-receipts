defmodule Receipts.AuctionItem do
  @derive Jason.Encoder
  @enforce_keys [:item_id, :short_title, :title, :description, :fair_market_value, :categories]
  defstruct [:item_id, :short_title, :title, :description, :fair_market_value, :categories]

  @type t :: %__MODULE__{
    item_id: integer(),
    short_title: String.t(),
    title: String.t(),
    description: String.t(),
    fair_market_value: integer(),
    categories: String.t()
  }

  def new(attrs) do
    %__MODULE__{
      item_id: parse_integer(attrs[:item_id]),
      short_title: attrs[:short_title] || "",
      title: attrs[:title] || "",
      description: attrs[:description] || "",
      fair_market_value: parse_integer(attrs[:fair_market_value]),
      categories: attrs[:categories] || ""
    }
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_integer(_), do: 0
end
