defmodule Receipts.AuctionItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :item_id, :integer
    field :short_title, :string
    field :title, :string
    field :description, :string
    field :fair_market_value, :integer
    field :categories, :string
    field :special_instructions, :string
    field :expiration_date, :string
  end

  def new(attrs) do
    attrs
    |> changeset()
    |> apply_action!(:insert)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :item_id,
      :short_title,
      :title,
      :description,
      :fair_market_value,
      :categories,
      :special_instructions,
      :expiration_date
    ])
    |> apply_defaults()
    |> normalize_text_fields()
  end

  defp normalize_text_fields(changeset) do
    changeset
    |> update_change(:short_title, &TextNormalizer.normalize/1)
    |> update_change(:title, &TextNormalizer.normalize/1)
    |> update_change(:description, &TextNormalizer.normalize/1)
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default(:item_id, 0)
    |> put_default(:short_title, "")
    |> put_default(:title, "")
    |> put_default(:description, "")
    |> put_default(:fair_market_value, 0)
    |> put_default(:categories, "")
    |> put_default(:special_instructions, "")
    |> put_default(:expiration_date, "")
  end

  defp put_default(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      "" when field in [:item_id, :fair_market_value] -> put_change(changeset, field, default)
      _ -> changeset
    end
  end
end
