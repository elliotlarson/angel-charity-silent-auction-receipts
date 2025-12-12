defmodule Mix.Tasks.ReportImportDataChanges do
  @moduledoc """
  Reports changes between consecutive CSV imports of auction item data.

  This task compares CSV files in chronological order and shows:
  - New items added
  - Items deleted
  - Items updated (with specific field changes)

  ## Usage

      mix report_import_data_changes

  """
  use Mix.Task

  alias Receipts.Config

  NimbleCSV.define(ReportCSVParser, separator: ",", escape: "\"")

  @shortdoc "Report changes between consecutive CSV imports"

  def run(_args) do
    Mix.shell().info("Auction Item CSV Change Report")
    Mix.shell().info("=" |> String.duplicate(80))
    Mix.shell().info("")

    csv_files = list_csv_files()

    if length(csv_files) == 0 do
      Mix.shell().error("No CSV files found in #{Config.csv_dir()}")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(csv_files)} CSV file(s):")

    csv_files
    |> Enum.each(fn file ->
      Mix.shell().info("  - #{file}")
    end)

    Mix.shell().info("")
  end

  defp list_csv_files do
    csv_dir = Config.csv_dir()

    case File.ls(csv_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".csv"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp parse_csv(filename) do
    csv_path = Path.join(Config.csv_dir(), filename)

    rows =
      csv_path
      |> File.stream!()
      |> ReportCSVParser.parse_stream()
      |> Enum.to_list()

    # First row is headers, rest are data rows
    [headers | data_rows] = rows

    # Find column indices for required fields
    qtego_idx = find_header_index(headers, "QTEGO #")
    title_idx = find_header_index(headers, "ITEM DONATED TITLE")
    value_idx = find_header_index(headers, "VALUE")
    desc_idx = find_header_index(headers, "DETAILED ITEM DESCRIPTION")

    # Build map keyed by Qtego #
    data_rows
    |> Enum.reduce(%{}, fn row, acc ->
      qtego = get_column(row, qtego_idx)

      # Skip items with empty Qtego #
      if qtego == "" do
        acc
      else
        item_data = %{
          qtego: qtego,
          title: get_column(row, title_idx),
          price: get_column(row, value_idx),
          description: get_column(row, desc_idx)
        }

        Map.put(acc, qtego, item_data)
      end
    end)
  end

  defp find_header_index(headers, target_header) do
    headers
    |> Enum.find_index(fn header ->
      String.upcase(String.trim(header)) == target_header
    end)
  end

  defp get_column(row, index) when is_integer(index) do
    row
    |> Enum.at(index, "")
    |> to_string()
    |> String.trim()
  end

  defp get_column(_row, nil), do: ""

  defp compare_csv_files(file1_data, file2_data) do
    file1_keys = MapSet.new(Map.keys(file1_data))
    file2_keys = MapSet.new(Map.keys(file2_data))

    # New items: in file2 but not in file1
    new_keys = MapSet.difference(file2_keys, file1_keys)
    new_items =
      new_keys
      |> Enum.map(fn key -> Map.get(file2_data, key) end)
      |> Enum.sort_by(& &1.qtego)

    # Deleted items: in file1 but not in file2
    deleted_keys = MapSet.difference(file1_keys, file2_keys)
    deleted_items =
      deleted_keys
      |> Enum.map(fn key -> Map.get(file1_data, key) end)
      |> Enum.sort_by(& &1.qtego)

    # Items in both files - check for updates
    common_keys = MapSet.intersection(file1_keys, file2_keys)
    updated_items =
      common_keys
      |> Enum.map(fn key ->
        item1 = Map.get(file1_data, key)
        item2 = Map.get(file2_data, key)
        detect_changes(item1, item2)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.qtego)

    %{
      new: new_items,
      deleted: deleted_items,
      updated: updated_items
    }
  end

  defp detect_changes(item1, item2) do
    changes = []

    # Check price changes
    changes =
      if normalize_for_comparison(item1.price) != normalize_for_comparison(item2.price) do
        [{:price, item1.price, item2.price} | changes]
      else
        changes
      end

    # Check title changes
    changes =
      if normalize_for_comparison(item1.title) != normalize_for_comparison(item2.title) do
        [{:title, item1.title, item2.title} | changes]
      else
        changes
      end

    # Check description changes (only report that it changed, not full diff)
    changes =
      if normalize_for_comparison(item1.description) != normalize_for_comparison(item2.description) do
        [{:description, :changed} | changes]
      else
        changes
      end

    # If there are changes, return the updated item with changes
    if length(changes) > 0 do
      %{
        qtego: item2.qtego,
        title: item2.title,
        price: item2.price,
        changes: Enum.reverse(changes)
      }
    else
      nil
    end
  end

  defp normalize_for_comparison(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp format_report(file1_name, file2_name, comparison) do
    separator = String.duplicate("=", 80)
    subseparator = String.duplicate("-", 80)

    new_count = length(comparison.new)
    deleted_count = length(comparison.deleted)
    updated_count = length(comparison.updated)

    report = []

    # Header
    report = [separator | report]
    report = ["Changes from #{file1_name} to #{file2_name}" | report]
    report = [separator | report]
    report = ["" | report]

    # New items section
    report =
      if new_count > 0 do
        new_items_lines =
          comparison.new
          |> Enum.map(fn item ->
            "#{item.qtego}: #{item.title} (#{item.price})"
          end)

        ["" | new_items_lines ++ [subseparator, "NEW ITEMS (#{new_count})" | report]]
      else
        report
      end

    # Deleted items section
    report =
      if deleted_count > 0 do
        deleted_items_lines =
          comparison.deleted
          |> Enum.map(fn item ->
            "#{item.qtego}: #{item.title} (#{item.price})"
          end)

        ["" | deleted_items_lines ++ [subseparator, "DELETED ITEMS (#{deleted_count})" | report]]
      else
        report
      end

    # Updated items section
    report =
      if updated_count > 0 do
        updated_items_lines =
          comparison.updated
          |> Enum.flat_map(fn item ->
            header = "#{item.qtego}: #{item.title} (#{item.price})"

            changes =
              item.changes
              |> Enum.map(fn
                {:price, old_val, new_val} ->
                  "  • Price changed from: #{old_val}, to: #{new_val}"

                {:title, old_val, new_val} ->
                  "  • Title changed from: \"#{old_val}\", to: \"#{new_val}\""

                {:description, :changed} ->
                  "  • Description changed"
              end)

            [header | changes]
          end)

        ["" | updated_items_lines ++ [subseparator, "UPDATED ITEMS (#{updated_count})" | report]]
      else
        report
      end

    # Summary
    report = [separator | report]
    report = ["Summary: #{new_count} new, #{deleted_count} deleted, #{updated_count} updated" | report]
    report = [separator | report]
    report = ["" | report]

    # Reverse to get correct order and join
    report
    |> Enum.reverse()
    |> Enum.join("\n")
  end
end
