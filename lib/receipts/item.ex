defmodule Receipts.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :item_identifier, :integer
    has_many :line_items, Receipts.LineItem

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = item \\ %__MODULE__{}, attrs) do
    item
    |> cast(attrs, [:item_identifier])
    |> validate_required([:item_identifier])
    |> validate_number(:item_identifier, greater_than: 0)
    |> unique_constraint(:item_identifier)
  end
end
