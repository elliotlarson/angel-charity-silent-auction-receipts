defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config
  alias Receipts.Repo

  import Ecto.Query

  NimbleCSV.define(CSVParser, separator: ",", escape: "\"")

  @shortdoc "Process auction items CSV files and save to database"

  @field_mappings %{
    "ITEM ID" => :item_identifier,
    "CATEGORIES (OPTIONAL)" => :categories,
    "15 CHARACTER DESCRIPTION" => :short_title,
    "100 CHARACTER DESCRIPTION" => :title,
    "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
    "FAIR MARKET VALUE" => :fair_market_value
  }

  def run(args) do
    Application.ensure_all_started(:receipts)
    Application.ensure_all_started(:req)

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

    Mix.shell().info("Processing #{filename}...")

    csv_path
    |> read_and_parse_csv()
    |> process_rows(opts)

    item_count = Repo.aggregate(Item, :count)
    line_item_count = Repo.aggregate(LineItem, :count)

    Mix.shell().info("\nProcessing complete!")
    Mix.shell().info("Total items in database: #{item_count}")
    Mix.shell().info("Total line items in database: #{line_item_count}")
  end

  @doc false
  def read_and_parse_csv(path) do
    path
    |> File.stream!()
    |> CSVParser.parse_stream()
    |> Enum.to_list()
  end

  defp process_rows(rows, opts) do
    [_title_row, headers, _empty_row | data_rows] = rows

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?/1)
    total = length(valid_rows)
    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    stats = %{new_items: 0, new_line_items: 0, updated: 0, skipped: 0}

    stats =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce(stats, fn {row, index}, acc ->
        process_row(row, headers, index, total, skip_ai, acc)
      end)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new_items}")
    Mix.shell().info("  New line items: #{stats.new_line_items}")
    Mix.shell().info("  Updated line items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")

    stats
  end

  defp process_row(row, headers, index, total, skip_ai, stats) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_identifier_str = get_column(row, find_header_index(headers, "ITEM ID"))
    item_identifier = String.to_integer(item_identifier_str)

    # Find or create Item
    {item, item_created} = find_or_create_item(item_identifier)

    # Check for existing line item by csv_row_hash
    existing_line_item =
      Repo.one(
        from li in LineItem,
          where: li.item_id == ^item.id and li.csv_row_hash == ^csv_row_hash
      )

    stats = if item_created, do: %{stats | new_items: stats.new_items + 1}, else: stats

    cond do
      not is_nil(existing_line_item) ->
        Mix.shell().info("[#{index}/#{total}] Skipped line item for ##{item_identifier} (unchanged)")
        %{stats | skipped: stats.skipped + 1}

      true ->
        # New line item - process and insert
        identifier = LineItem.next_identifier(item.id)
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id, skip_ai: skip_ai)
        attrs_with_identifier = Map.put(attrs, :identifier, identifier)
        changeset = LineItem.changeset(%LineItem{}, attrs_with_identifier)
        {:ok, _line_item} = Repo.insert(changeset)
        Mix.shell().info("[#{index}/#{total}] Created line item for ##{item_identifier}")
        %{stats | new_line_items: stats.new_line_items + 1}
    end
  end

  defp find_or_create_item(item_identifier) do
    case Repo.get_by(Item, item_identifier: item_identifier) do
      nil ->
        {:ok, item} =
          %Item{}
          |> Item.changeset(%{item_identifier: item_identifier})
          |> Repo.insert()
        {item, true}

      item ->
        {item, false}
    end
  end

  defp hash_csv_row(csv_line) do
    :crypto.hash(:sha256, csv_line)
    |> Base.encode16(case: :lower)
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

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, item_id, opts) do
    attrs =
      @field_mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        value =
          case find_header_index(headers, header) do
            nil -> ""
            index -> get_column(row, index)
          end

        normalized_value =
          case {field_name, value} do
            {field, ""} when field in [:item_identifier, :fair_market_value] -> nil
            _ -> value
          end

        Map.put(acc, field_name, normalized_value)
      end)

    attrs
    |> Map.put(:item_id, item_id)
    |> Map.put(:csv_row_hash, csv_row_hash)
    |> Map.put(:csv_raw_line, csv_raw_line)
    |> AIDescriptionProcessor.process(opts)
  end

  defp find_header_index(headers, target_header) do
    headers
    |> Enum.find_index(fn header ->
      String.upcase(String.trim(header)) == target_header
    end)
  end
end
