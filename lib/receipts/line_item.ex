defmodule Receipts.LineItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Receipts.TextNormalizer
  alias Receipts.HtmlFormatter

  @derive Jason.Encoder
  schema "line_items" do
    field(:identifier, :integer)
    field(:short_title, :string)
    field(:title, :string)
    field(:description, :string)
    field(:fair_market_value, :integer)
    field(:categories, :string)
    field(:notes, :string)
    field(:expiration_notice, :string)
    field(:csv_row_hash, :string)
    field(:csv_raw_line, :string)

    belongs_to(:item, Receipts.Item)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = line_item \\ %__MODULE__{}, attrs) do
    line_item
    |> cast(attrs, [
      :item_id,
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
  Returns the next available numeric identifier for a given item.
  Queries existing line items for the item and returns the next number in sequence.

  Examples:
    - No existing line items: returns 1
    - Existing line items with 1: returns 2
    - Existing line items with 1, 2: returns 3
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
      nil -> 1
      identifier -> identifier + 1
    end
  end

  @doc """
  Returns the total count of line items for this line item's parent item.
  Used to determine if we should include "X of Y" in filenames and display.
  """
  def count_for_item(item_id) do
    import Ecto.Query
    alias Receipts.Repo

    from(li in __MODULE__,
      where: li.item_id == ^item_id,
      select: count(li.id)
    )
    |> Repo.one()
  end

  @doc """
  Generates the base filename for receipts.
  Expects line_item to have :item association preloaded.

  Examples:
    - Single line item: "receipt_103_landscaping"
    - Multiple line items: "receipt_139_1_of_3_ac_hotel"
  """
  def receipt_filename(line_item) do
    alias Receipts.Repo

    # Preload item if not already loaded
    line_item = Repo.preload(line_item, :item)

    snake_case_title =
      line_item.short_title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")

    total = count_for_item(line_item.item_id)

    if total > 1 do
      "receipt_#{line_item.item.item_identifier}_#{line_item.identifier}_of_#{total}_#{snake_case_title}"
    else
      "receipt_#{line_item.item.item_identifier}_#{snake_case_title}"
    end
  end
end
