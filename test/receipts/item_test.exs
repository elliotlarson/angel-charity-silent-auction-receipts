defmodule Receipts.ItemTest do
  use Receipts.DataCase

  alias Receipts.Item

  describe "changeset/2" do
    test "valid with item_identifier" do
      changeset = Item.changeset(%Item{}, %{item_identifier: 139})
      assert changeset.valid?
    end

    test "requires item_identifier" do
      changeset = Item.changeset(%Item{}, %{})
      refute changeset.valid?
      assert %{item_identifier: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires positive item_identifier" do
      changeset = Item.changeset(%Item{}, %{item_identifier: 0})
      refute changeset.valid?
      assert %{item_identifier: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
