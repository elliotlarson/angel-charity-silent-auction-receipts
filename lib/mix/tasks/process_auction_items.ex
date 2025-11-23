defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.AuctionItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config

  @shortdoc "Process auction items CSV files and convert to JSON"

  @field_mappings %{
    "ITEM ID" => :item_id,
    "CATEGORIES (OPTIONAL)" => :categories,
    "15 CHARACTER DESCRIPTION" => :short_title,
    "100 CHARACTER DESCRIPTION" => :title,
    "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
    "FAIR MARKET VALUE" => :fair_market_value
  }

  def run(args) do
    # Start required applications
    Application.ensure_all_started(:req)

    # Load .env file if it exists
    if File.exists?(".env") do
      {:ok, vars} = Dotenvy.source(".env")
      Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)
    end

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [skip_ai_processing: :boolean],
        aliases: [s: :skip_ai_processing]
      )

    csv_files = list_csv_files()

    case csv_files do
      [] ->
        Mix.shell().error("No CSV files found in #{Config.csv_dir()}")

      files ->
        selected_file = prompt_file_selection(files)
        process_file(selected_file, opts)
    end
  end

  defp list_csv_files do
    case File.ls(Config.csv_dir()) do
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

    input = Mix.shell().prompt("Select file number:") |> String.trim()

    case Integer.parse(input) do
      {selection, _} when selection > 0 and selection <= length(files) ->
        Enum.at(files, selection - 1)

      _ ->
        Mix.shell().error("Invalid selection. Please enter a number between 1 and #{length(files)}")
        prompt_file_selection(files)
    end
  end

  defp process_file(filename, opts) do
    csv_path = Path.join(Config.csv_dir(), filename)
    json_filename = Path.basename(filename, ".csv") <> ".json"
    json_path = Path.join(Config.json_dir(), json_filename)

    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    unless skip_ai do
      Mix.shell().info("AI processing enabled - this may take a few minutes...")
    end

    items =
      csv_path
      |> read_and_parse_csv()
      |> clean_data(opts)

    json_content = Jason.encode!(items, pretty: true)
    File.write!(json_path, json_content)

    Mix.shell().info("Successfully processed #{length(items)} items")
    Mix.shell().info("Output saved to: #{json_path}")
  end

  @doc false
  def read_and_parse_csv(path) do
    path
    |> File.stream!()
    |> Mix.Tasks.ProcessAuctionItems.CSV.decode()
    |> Enum.to_list()
  end

  @doc false
  def clean_data(rows, opts \\ []) do
    [_title_row, headers, _empty_row | data_rows] = rows

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?/1)
    total = length(valid_rows)
    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    valid_rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, index} ->
      item = build_item(row, headers, opts)

      unless skip_ai do
        Mix.shell().info("Processed item #{index}/#{total} (ID: #{item.item_id})")
      end

      item
    end)
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
  def build_item(row, headers, opts \\ []) do
    attrs =
      @field_mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        value =
          case find_header_index(headers, header) do
            nil -> ""
            index -> get_column(row, index)
          end

        # Convert empty strings to nil for integer fields so Ecto defaults apply
        normalized_value =
          case {field_name, value} do
            {field, ""} when field in [:item_id, :fair_market_value] -> nil
            _ -> value
          end

        Map.put(acc, field_name, normalized_value)
      end)

    attrs
    |> AIDescriptionProcessor.process(opts)
    |> AuctionItem.new()
  end

  defp find_header_index(headers, target_header) do
    headers
    |> Enum.find_index(fn header ->
      String.upcase(String.trim(header)) == target_header
    end)
  end
end
