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
    field :notes, :string
    field :expiration_notice, :string
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
      :notes,
      :expiration_notice
    ])
    |> apply_defaults()
    |> normalize_text_fields()
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default(:item_id, 0)
    |> put_default(:short_title, "")
    |> put_default(:title, "")
    |> put_default(:description, "")
    |> put_default(:fair_market_value, 0)
    |> put_default(:categories, "")
    |> put_default(:notes, "")
    |> put_default(:expiration_notice, "")
  end

  defp put_default(changeset, field, default) do
    value = get_field(changeset, field)
    in_changes = Map.has_key?(changeset.changes, field)

    should_apply =
      case {field, value, in_changes} do
        {_, nil, _} -> true
        {f, "", _} when f in [:item_id, :fair_market_value] -> true
        {_, _, false} -> true  # Not in changes, apply default explicitly
        _ -> false
      end

    if should_apply do
      put_change(changeset, field, default)
    else
      changeset
    end
  end

  defp normalize_text_fields(changeset) do
    changeset
    |> update_change(:short_title, &TextNormalizer.normalize/1)
    |> update_change(:title, &TextNormalizer.normalize/1)
    |> update_change(:description, &TextNormalizer.normalize/1)
  end
end
