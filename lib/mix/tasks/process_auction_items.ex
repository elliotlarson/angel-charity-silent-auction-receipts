defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.AuctionItem
  alias Receipts.AIDescriptionProcessor
  alias Receipts.Config
  alias Receipts.Repo

  NimbleCSV.define(CSVParser, separator: ",", escape: "\"")

  @shortdoc "Process auction items CSV files and save to database"

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
    Application.ensure_all_started(:receipts)
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

    Mix.shell().info("Processing #{filename}...")

    csv_path
    |> read_and_parse_csv()
    |> process_rows(opts)

    Mix.shell().info("\nProcessing complete!")
    Mix.shell().info("Total items in database: #{Repo.aggregate(AuctionItem, :count)}")
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

    stats = %{new: 0, updated: 0, skipped: 0}

    stats =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce(stats, fn {row, index} ->
        process_row(row, headers, index, total, skip_ai, stats)
      end)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new}")
    Mix.shell().info("  Updated items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")

    stats
  end

  defp process_row(row, headers, index, total, skip_ai, stats) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_id_str = get_column(row, find_header_index(headers, "ITEM ID"))
    item_id = String.to_integer(item_id_str)

    existing = Repo.get_by(AuctionItem, item_id: item_id)

    cond do
      is_nil(existing) ->
        # New item - process and insert
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, skip_ai: skip_ai)
        changeset = AuctionItem.changeset(%AuctionItem{}, attrs)
        {:ok, _item} = Repo.insert(changeset)
        Mix.shell().info("[#{index}/#{total}] Created item ##{item_id}")
        %{stats | new: stats.new + 1}

      existing.csv_row_hash == csv_row_hash ->
        # Unchanged - skip processing
        Mix.shell().info("[#{index}/#{total}] Skipped item ##{item_id} (unchanged)")
        %{stats | skipped: stats.skipped + 1}

      true ->
        # Changed - reprocess and update
        attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, skip_ai: skip_ai)
        changeset = AuctionItem.changeset(existing, attrs)
        {:ok, _item} = Repo.update(changeset)
        Mix.shell().info("[#{index}/#{total}] Updated item ##{item_id}")
        %{stats | updated: stats.updated + 1}
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

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, opts) do
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
