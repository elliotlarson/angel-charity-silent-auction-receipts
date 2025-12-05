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

  @doc false
  def detect_format(headers) do
    header_strings = Enum.map(headers, &String.upcase(String.trim(&1)))

    cond do
      "ITEM ID" in header_strings -> :old_format
      "TAG #" in header_strings -> :new_format
      true -> :unknown
    end
  end

  @doc false
  def field_mappings(:old_format) do
    %{
      "CATEGORIES (OPTIONAL)" => :categories,
      "15 CHARACTER DESCRIPTION" => :short_title,
      "100 CHARACTER DESCRIPTION" => :title,
      "1500 CHARACTER DESCRIPTION (OPTIONAL)" => :description,
      "FAIR MARKET VALUE" => :fair_market_value,
      "ITEM ID" => :item_identifier
    }
  end

  def field_mappings(:new_format) do
    %{
      "CATEGORY" => :categories,
      "ITEM DONATED TITLE" => :title,
      "DETAILED ITEM DESCRIPTION" => :description,
      "VALUE" => :fair_market_value,
      "TAG #" => :item_identifier
    }
  end

  @doc false
  def extract_numeric_identifier(tag) do
    tag
    |> String.replace(~r/[^0-9]/, "")
    |> String.trim_leading("0")
    |> case do
      "" -> "0"
      num -> num
    end
  end

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
        Mix.shell().error(
          "Invalid selection. Please enter a number between 1 and #{length(files)}"
        )

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
    # Detect format by checking first few rows for headers
    {format, header_row_index} = detect_format_and_structure(rows)

    case format do
      :unknown ->
        Mix.shell().error("Unknown CSV format. Could not detect ITEM ID or TAG # header.")
        Mix.shell().error("First few rows: #{inspect(Enum.take(rows, 3))}")
        %{new_items: 0, new_line_items: 0, updated: 0, skipped: 0, deleted: 0, deleted_items: 0}

      _ ->
        Mix.shell().info("Detected CSV format: #{format}")
        process_rows_with_format(rows, format, header_row_index, opts)
    end
  end

  defp detect_format_and_structure(rows) do
    # Check first 5 rows to find headers
    rows
    |> Enum.take(5)
    |> Enum.with_index()
    |> Enum.find_value({:unknown, 0}, fn {row, index} ->
      case detect_format(row) do
        :unknown -> nil
        format -> {format, index}
      end
    end)
  end

  defp process_rows_with_format(rows, format, header_row_index, opts) do
    headers = Enum.at(rows, header_row_index)

    # Data rows start after headers (skip empty row for old format)
    data_row_start =
      case format do
        # Skip empty row after headers
        :old_format -> header_row_index + 2
        # Data immediately after headers
        :new_format -> header_row_index + 1
      end

    data_rows = Enum.drop(rows, data_row_start)

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?(&1, headers, format))
    total = length(valid_rows)
    skip_ai = Keyword.get(opts, :skip_ai_processing, false)

    stats = %{
      new_items: 0,
      new_line_items: 0,
      updated: 0,
      skipped: 0,
      deleted: 0,
      deleted_items: 0
    }

    # Group rows by item_identifier to determine position within each item
    rows_by_item = group_rows_by_item(valid_rows, headers, format)

    # Track which line items we've processed from CSV
    {stats, processed_line_item_ids} =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce({stats, MapSet.new()}, fn {row, csv_index}, {acc, seen} ->
        item_identifier_str = get_item_identifier(row, headers, format)
        item_identifier = String.to_integer(item_identifier_str)
        position = get_position_within_item(row, rows_by_item[item_identifier])

        {updated_stats, line_item_id} =
          process_row(row, headers, csv_index, total, position, skip_ai, acc, format)

        {updated_stats, MapSet.put(seen, line_item_id)}
      end)

    # Delete line items that are no longer in the CSV
    stats = delete_removed_line_items(processed_line_item_ids, stats)

    # Delete items that no longer have any line items
    stats = delete_empty_items(stats)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new_items}")
    Mix.shell().info("  New line items: #{stats.new_line_items}")
    Mix.shell().info("  Updated line items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")
    Mix.shell().info("  Deleted items: #{stats.deleted_items}")
    Mix.shell().info("  Deleted line items: #{stats.deleted}")

    stats
  end

  defp group_rows_by_item(rows, headers, format) do
    rows
    |> Enum.group_by(fn row ->
      item_identifier_str = get_item_identifier(row, headers, format)
      String.to_integer(item_identifier_str)
    end)
  end

  defp get_item_identifier(row, headers, format) do
    header =
      case format do
        :old_format -> "ITEM ID"
        :new_format -> "TAG #"
      end

    raw_value = get_column(row, find_header_index(headers, header))

    case format do
      :old_format -> raw_value
      :new_format -> extract_numeric_identifier(raw_value)
    end
  end

  defp get_position_within_item(row, rows_for_item) do
    Enum.find_index(rows_for_item, fn r -> r == row end) + 1
  end

  defp process_row(row, headers, csv_index, total, identifier, skip_ai, stats, format) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_identifier_str = get_item_identifier(row, headers, format)
    item_identifier = String.to_integer(item_identifier_str)

    # Find or create Item
    {item, item_created} = find_or_create_item(item_identifier)
    stats = if item_created, do: %{stats | new_items: stats.new_items + 1}, else: stats

    # Find existing line item by item_id + identifier (position)
    existing_by_position =
      Repo.one(
        from(li in LineItem,
          where: li.item_id == ^item.id and li.identifier == ^identifier
        )
      )

    {stats, line_item_id} =
      cond do
        # Same position, same hash - unchanged, skip
        not is_nil(existing_by_position) and existing_by_position.csv_row_hash == csv_row_hash ->
          Mix.shell().info(
            "[#{csv_index}/#{total}] Skipped line item for ##{item_identifier} (unchanged)"
          )

          {%{stats | skipped: stats.skipped + 1}, existing_by_position.id}

        # Same position, different hash - data changed, update
        not is_nil(existing_by_position) ->
          attrs =
            build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id, format,
              skip_ai: skip_ai
            )

          changeset = LineItem.changeset(existing_by_position, attrs)
          {:ok, updated_item} = Repo.update(changeset)
          Mix.shell().info("[#{csv_index}/#{total}] Updated line item for ##{item_identifier}")
          {%{stats | updated: stats.updated + 1}, updated_item.id}

        # New line item - process and insert
        true ->
          attrs =
            build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id, format,
              skip_ai: skip_ai
            )

          attrs_with_identifier = Map.put(attrs, :identifier, identifier)
          changeset = LineItem.changeset(%LineItem{}, attrs_with_identifier)
          {:ok, new_item} = Repo.insert(changeset)
          Mix.shell().info("[#{csv_index}/#{total}] Created line item for ##{item_identifier}")
          {%{stats | new_line_items: stats.new_line_items + 1}, new_item.id}
      end

    {stats, line_item_id}
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
  def is_placeholder_row?(row, headers, format) do
    item_id = get_item_identifier(row, headers, format)

    fmv_header =
      case format do
        :old_format -> "FAIR MARKET VALUE"
        :new_format -> "VALUE"
      end

    fair_market_value = get_column(row, find_header_index(headers, fmv_header))

    item_id in ["", "0"] or fair_market_value in ["", "0", "$0", "$0.00"]
  end

  @doc false
  def get_column(row, index) do
    row
    |> Enum.at(index, "")
    |> to_string()
    |> String.trim()
  end

  @doc false
  def parse_currency(value) do
    value
    |> String.replace(~r/[$,\s]/, "")
    |> String.split(".")
    |> List.first()
    |> case do
      "" -> ""
      num -> num
    end
  end

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, item_id, format, opts) do
    mappings = field_mappings(format)

    attrs =
      mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        # Skip item_identifier field - it's not a LineItem field
        if field_name == :item_identifier do
          acc
        else
          value =
            case find_header_index(headers, header) do
              nil -> ""
              index -> get_column(row, index)
            end

          normalized_value =
            case {field_name, value, format} do
              {:fair_market_value, "", _} -> nil
              {:fair_market_value, val, :new_format} -> parse_currency(val)
              _ -> value
            end

          Map.put(acc, field_name, normalized_value)
        end
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

  defp delete_removed_line_items(processed_line_item_ids, stats) do
    # Find all line items in database that weren't in the CSV
    all_line_item_ids =
      Repo.all(from(li in LineItem, select: li.id))
      |> MapSet.new()

    removed_ids = MapSet.difference(all_line_item_ids, processed_line_item_ids)

    if MapSet.size(removed_ids) > 0 do
      Mix.shell().info("\nDeleting #{MapSet.size(removed_ids)} line items no longer in CSV...")

      {deleted_count, _} =
        from(li in LineItem, where: li.id in ^MapSet.to_list(removed_ids))
        |> Repo.delete_all()

      %{stats | deleted: deleted_count}
    else
      stats
    end
  end

  defp delete_empty_items(stats) do
    # Find items that have no line items
    empty_item_ids =
      from(i in Item,
        left_join: li in assoc(i, :line_items),
        group_by: i.id,
        having: count(li.id) == 0,
        select: i.id
      )
      |> Repo.all()

    if length(empty_item_ids) > 0 do
      Mix.shell().info("Deleting #{length(empty_item_ids)} items with no line items...")

      {deleted_count, _} =
        from(i in Item, where: i.id in ^empty_item_ids)
        |> Repo.delete_all()

      %{stats | deleted_items: deleted_count}
    else
      stats
    end
  end
end
