defmodule Receipts.AuctionItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

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
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end

  def changeset(%__MODULE__{} = item \\ %__MODULE__{}, attrs) do
    item
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
    |> ensure_non_negative_integers()
    |> normalize_text_fields()
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default_if_nil_or_empty(:item_id, 0)
    |> put_default_if_nil_or_empty(:fair_market_value, 0)
    |> put_default_if_nil(:short_title, "")
    |> put_default_if_nil(:title, "")
    |> put_default_if_nil(:description, "")
    |> put_default_if_nil(:categories, "")
    |> put_default_if_nil(:notes, "")
    |> put_default_if_nil(:expiration_notice, "")
  end

  defp put_default_if_nil(changeset, field, default) do
    if get_field(changeset, field) == nil do
      put_change(changeset, field, default)
    else
      changeset
    end
  end

  defp put_default_if_nil_or_empty(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      "" -> put_change(changeset, field, default)
      _ -> changeset
    end
  end

  defp ensure_non_negative_integers(changeset) do
    changeset
    |> update_change(:item_id, &max(&1, 0))
    |> update_change(:fair_market_value, &max(&1, 0))
  end

  defp normalize_text_fields(changeset) do
    changeset
    |> update_change(:short_title, &TextNormalizer.normalize/1)
    |> update_change(:title, &TextNormalizer.normalize/1)
    |> update_change(:description, &normalize_and_format_description/1)
  end

  defp normalize_and_format_description(text) do
    text
    |> TextNormalizer.normalize()
    |> HtmlFormatter.format_description()
  end
end
