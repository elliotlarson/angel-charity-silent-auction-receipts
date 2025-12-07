defmodule Receipts.LineItemTest do
  use Receipts.DataCase
  import Ecto.Changeset, only: [get_change: 2]

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.Repo

  defp create_item(item_identifier) do
    %Item{}
    |> Item.changeset(%{item_identifier: item_identifier})
    |> Repo.insert!()
  end

  defp sample_attrs(item, overrides) do
    Map.merge(
      %{
        item_id: item.id,
        identifier: 1,
        title: "Test",
        csv_row_hash: "abc123",
        csv_raw_line: "103,HOME,Landscaping,One Year Monthly Landscaping Services,..."
      },
      overrides
    )
  end

  describe "changeset/2" do
    test "valid with required fields" do
      item = create_item(103)
      attrs = sample_attrs(item, %{title: "Test"})

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
    end

    test "requires item_id" do
      changeset =
        LineItem.changeset(%LineItem{}, %{
          csv_row_hash: "abc123",
          csv_raw_line: "raw"
        })

      refute changeset.valid?
      assert %{item_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "casts string integers to integers" do
      item = create_item(103)

      attrs =
        sample_attrs(item, %{
          value: "1200"
        })

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :value) == 1200
    end

    test "normalizes text fields" do
      item = create_item(1)

      attrs =
        sample_attrs(item, %{
          title: "services .",
          description: "This is  a test.Good stuff !"
        })

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "services."
      assert get_change(changeset, :description) == "<p>This is a test. Good stuff!</p>"
    end

    test "converts negative value to 0" do
      item = create_item(130)
      attrs = sample_attrs(item, %{value: "-1"})

      changeset = LineItem.changeset(%LineItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :value) == 0
    end
  end

  describe "slug generation" do
    test "generates slug from title" do
      item = create_item(103)
      attrs = sample_attrs(item, %{title: "Landscaping Services"})
      changeset = LineItem.changeset(%LineItem{}, attrs)
      assert changeset.changes.slug == "landscaping_services"
    end

    test "removes special characters from slug" do
      item = create_item(103)
      attrs = sample_attrs(item, %{title: "Art & Wine Tasting!"})
      changeset = LineItem.changeset(%LineItem{}, attrs)
      assert changeset.changes.slug == "art_wine_tasting"
    end

    test "collapses multiple spaces in slug" do
      item = create_item(103)
      attrs = sample_attrs(item, %{title: "Premium   Spa   Package"})
      changeset = LineItem.changeset(%LineItem{}, attrs)
      assert changeset.changes.slug == "premium_spa_package"
    end
  end

  describe "receipt_filename/1" do
    test "generates filename with slug for single item" do
      item = create_item(103)

      line_item =
        %LineItem{
          slug: "landscaping_services",
          item_id: item.id,
          identifier: 1
        }
        |> Map.put(:item, item)

      assert LineItem.receipt_filename(line_item) == "receipt_103_landscaping_services"
    end

    test "generates filename with slug for multiple items" do
      item = create_item(139)

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 1,
        title: "Item 1",
        slug: "item_1",
        csv_row_hash: "hash1",
        csv_raw_line: "raw1"
      })

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 2,
        title: "Item 2",
        slug: "item_2",
        csv_row_hash: "hash2",
        csv_raw_line: "raw2"
      })

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 3,
        title: "Item 3",
        slug: "item_3",
        csv_row_hash: "hash3",
        csv_raw_line: "raw3"
      })

      line_item =
        %LineItem{
          slug: "ac_hotel",
          item_id: item.id,
          identifier: 2
        }
        |> Map.put(:item, item)

      assert LineItem.receipt_filename(line_item) == "receipt_139_2_of_3_ac_hotel"
    end
  end

  describe "next_identifier/1" do
    test "returns 1 when no line items exist for item" do
      item = create_item(999)
      assert LineItem.next_identifier(item.id) == 1
    end

    test "returns 2 when one line item exists" do
      item = create_item(100)

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 1,
        csv_row_hash: "hash1",
        csv_raw_line: "raw1"
      })

      assert LineItem.next_identifier(item.id) == 2
    end

    test "returns 3 when two line items exist" do
      item = create_item(101)

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 1,
        csv_row_hash: "hash1",
        csv_raw_line: "raw1"
      })

      Repo.insert!(%LineItem{
        item_id: item.id,
        identifier: 2,
        csv_row_hash: "hash2",
        csv_raw_line: "raw2"
      })

      assert LineItem.next_identifier(item.id) == 3
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
