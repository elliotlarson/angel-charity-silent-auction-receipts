defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  @shortdoc "Process auction items CSV files and convert to JSON"

  @csv_dir "db/auction_items/csv"
  @json_dir "db/auction_items/json"

  @field_mappings %{
    "ITEM ID" => :item_id,
    "CATEGORIES (OPTIONAL)" => :categories,
    "15 CHARACTER DESCRIPTION" => :short_title,
    "100 CHARACTER DESCRIPTION" => :title,
    "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
    "FAIR MARKET VALUE" => :fair_market_value
  }

  def run(_args) do
    csv_files = list_csv_files()

    case csv_files do
      [] ->
        Mix.shell().error("No CSV files found in #{@csv_dir}")
      files ->
        selected_file = prompt_file_selection(files)
        process_file(selected_file)
    end
  end

  defp list_csv_files do
    case File.ls(@csv_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".csv"))
        |> Enum.sort()
      {:error, _} ->
        []
    end
  end

  defp prompt_file_selection(files) do
    Mix.shell().info("Available CSV files:")

    files
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      Mix.shell().info("  #{index}. #{file}")
    end)

    selection = Mix.shell().prompt("Select file number:") |> String.trim() |> String.to_integer()
    Enum.at(files, selection - 1)
  end

  defp process_file(filename) do
    csv_path = Path.join(@csv_dir, filename)
    json_filename = Path.basename(filename, ".csv") <> ".json"
    json_path = Path.join(@json_dir, json_filename)

    items = csv_path
      |> read_and_parse_csv()
      |> clean_data()

    json_content = Jason.encode!(items, pretty: true)
    File.write!(json_path, json_content)

    Mix.shell().info("Successfully processed #{length(items)} items")
    Mix.shell().info("Output saved to: #{json_path}")
  end

  @doc false
  def read_and_parse_csv(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Mix.Tasks.ProcessAuctionItems.CSV.decode()
    |> Enum.to_list()
  end

  @doc false
  def clean_data(rows) do
    [_title_row, headers, _empty_row | data_rows] = rows

    data_rows
    |> Enum.reject(&is_placeholder_row?/1)
    |> Enum.map(&build_item(&1, headers))
  end

  @doc false
  def is_placeholder_row?(row) do
    item_id = get_column(row, 1)
    fair_market_value = get_column(row, 8)

    item_id in ["", "0"] or fair_market_value in ["", "0"]
  end

  @doc false
  def get_column(row, index) do
    row
    |> Enum.at(index, "")
    |> to_string()
    |> String.trim()
  end

  @doc false
  def build_item(row, headers) do
    @field_mappings
    |> Enum.reduce(%{}, fn {header, field_name}, acc ->
      case find_header_index(headers, header) do
        nil -> Map.put(acc, field_name, "")
        index -> Map.put(acc, field_name, get_column(row, index))
      end
    end)
  end

  defp find_header_index(headers, target_header) do
    headers
    |> Enum.find_index(fn header ->
      String.upcase(String.trim(header)) == target_header
    end)
  end
end
