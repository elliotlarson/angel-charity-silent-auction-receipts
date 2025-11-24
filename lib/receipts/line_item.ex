defmodule Receipts.LineItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

  @derive Jason.Encoder
  schema "line_items" do
    field :item_identifier, :integer
    field :identifier, :string
    field :short_title, :string
    field :title, :string
    field :description, :string
    field :fair_market_value, :integer
    field :categories, :string
    field :notes, :string
    field :expiration_notice, :string
    field :csv_row_hash, :string
    field :csv_raw_line, :string

    belongs_to :item, Receipts.Item

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = line_item \\ %__MODULE__{}, attrs) do
    line_item
    |> cast(attrs, [
      :item_id,
      :item_identifier,
      :identifier,
      :short_title,
      :title,
      :description,
      :fair_market_value,
      :categories,
      :notes,
      :expiration_notice,
      :csv_row_hash,
      :csv_raw_line
    ])
    |> apply_defaults()
    |> validate_required([:item_id, :identifier, :csv_row_hash, :csv_raw_line])
    |> ensure_non_negative_integers()
    |> normalize_text_fields()
    |> foreign_key_constraint(:item_id)
    |> unique_constraint([:item_id, :identifier])
  end

  defp apply_defaults(changeset) do
    changeset
    |> put_default_if_nil_or_empty(:item_identifier, 0)
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
    |> update_change(:item_identifier, &max(&1 || 0, 0))
    |> update_change(:fair_market_value, &max(&1 || 0, 0))
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

  @doc """
  Returns the next available letter identifier for a given item.
  Queries existing line items for the item and returns the next letter in sequence.

  Examples:
    - No existing line items: returns "a"
    - Existing line items with "a": returns "b"
    - Existing line items with "a", "b": returns "c"
  """
  def next_identifier(item_id) do
    import Ecto.Query
    alias Receipts.Repo

    max_identifier =
      from(li in __MODULE__,
        where: li.item_id == ^item_id,
        select: max(li.identifier)
      )
      |> Repo.one()

    case max_identifier do
      nil -> "a"
      identifier -> String.to_charlist(identifier) |> hd() |> Kernel.+(1) |> List.wrap() |> to_string()
    end
  end
end
