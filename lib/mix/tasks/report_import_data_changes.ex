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
end
