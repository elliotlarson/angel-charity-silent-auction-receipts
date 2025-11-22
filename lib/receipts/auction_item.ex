defmodule Receipts.AuctionItem do
  alias Receipts.TextNormalizer

  @derive Jason.Encoder
  @enforce_keys [:item_id, :short_title, :title, :description, :fair_market_value, :categories]
  defstruct [
    :item_id,
    :short_title,
    :title,
    :description,
    :fair_market_value,
    :categories,
    :special_instructions,
    :expiration_date
  ]

  @type t :: %__MODULE__{
          item_id: integer(),
          short_title: String.t(),
          title: String.t(),
          description: String.t(),
          fair_market_value: integer(),
          categories: String.t(),
          special_instructions: String.t(),
          expiration_date: String.t()
        }

  def new(attrs) do
    %__MODULE__{
      item_id: parse_integer(attrs[:item_id]),
      short_title: TextNormalizer.normalize(attrs[:short_title]),
      title: TextNormalizer.normalize(attrs[:title]),
      description: TextNormalizer.normalize(attrs[:description]),
      fair_market_value: parse_integer(attrs[:fair_market_value]),
      categories: attrs[:categories] || "",
      special_instructions: attrs[:special_instructions] || "",
      expiration_date: attrs[:expiration_date] || ""
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
