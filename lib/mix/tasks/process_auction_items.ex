defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.Config
  alias Receipts.Repo

  import Ecto.Query

  NimbleCSV.define(CSVParser, separator: ",", escape: "\"")

  @shortdoc "Process auction items CSV files and save to database"

  @doc false
  def field_mappings do
    %{
      "QTEGO #" => :item_identifier,
      "CATEGORY" => :categories,
      "ITEM DONATED TITLE" => :title,
      "DETAILED ITEM DESCRIPTION" => :description,
      "VALUE" => :value,
      "RESTRICTIONS" => :notes,
      "DATES/ EXPIRATION" => :expiration_notice
    }
  end

  def run(args) do
    Application.ensure_all_started(:receipts)
    Application.ensure_all_started(:req)

    if File.exists?(".env") do
      {:ok, vars} = Dotenvy.source(".env")
      Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)
    end

    {opts, positional_args, _} =
      OptionParser.parse(args, switches: [], aliases: [])

    csv_files = list_csv_files()

    case csv_files do
      [] ->
        Mix.shell().error("No CSV files found in #{Config.csv_dir()}")

      files ->
        selected_file =
          case positional_args do
            [filename] ->
              # File specified as argument
              if filename in files do
                filename
              else
                Mix.shell().error("File '#{filename}' not found in #{Config.csv_dir()}")
                Mix.shell().error("Available files: #{Enum.join(files, ", ")}")
                exit({:shutdown, 1})
              end

            [] ->
              # No file specified, prompt for selection
              prompt_file_selection(files)

            _ ->
              Mix.shell().error(
                "Usage: mix process_auction_items [filename] [--skip-ai-processing]"
              )

              exit({:shutdown, 1})
          end

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

  defp process_rows(rows, _opts) do
    [headers | data_rows] = rows

    valid_rows = Enum.reject(data_rows, &is_placeholder_row?(&1, headers))
    total = length(valid_rows)

    stats = %{
      new_items: 0,
      new_line_items: 0,
      updated: 0,
      skipped: 0,
      deleted: 0,
      deleted_items: 0,
      new_item_ids: MapSet.new(),
      updated_item_ids: MapSet.new(),
      deleted_item_ids: MapSet.new()
    }

    rows_by_item = group_rows_by_item(valid_rows, headers)

    {stats, processed_line_item_ids} =
      valid_rows
      |> Enum.with_index(1)
      |> Enum.reduce({stats, MapSet.new()}, fn {row, csv_index}, {acc, seen} ->
        item_identifier_str = get_item_identifier(row, headers)
        item_identifier = String.to_integer(item_identifier_str)
        position = get_position_within_item(row, rows_by_item[item_identifier])

        {updated_stats, line_item_id} =
          process_row(row, headers, csv_index, total, position, acc)

        {updated_stats, MapSet.put(seen, line_item_id)}
      end)

    stats = delete_removed_line_items(processed_line_item_ids, stats)
    stats = delete_empty_items(stats)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  New items: #{stats.new_items}")
    Mix.shell().info("  New line items: #{stats.new_line_items}")
    Mix.shell().info("  Updated line items: #{stats.updated}")
    Mix.shell().info("  Skipped (unchanged): #{stats.skipped}")
    Mix.shell().info("  Deleted items: #{stats.deleted_items}")
    Mix.shell().info("  Deleted line items: #{stats.deleted}")

    Mix.shell().info("\nItem Identifier Lists:")

    new_ids =
      stats.new_item_ids
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.join(",")

    Mix.shell().info("  New: #{if new_ids == "", do: "(none)", else: new_ids}")

    updated_ids =
      stats.updated_item_ids
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.join(",")

    Mix.shell().info("  Updated: #{if updated_ids == "", do: "(none)", else: updated_ids}")

    deleted_ids =
      stats.deleted_item_ids
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.join(",")

    Mix.shell().info("  Deleted: #{if deleted_ids == "", do: "(none)", else: deleted_ids}")

    stats
  end

  defp group_rows_by_item(rows, headers) do
    rows
    |> Enum.group_by(fn row ->
      item_identifier_str = get_item_identifier(row, headers)
      String.to_integer(item_identifier_str)
    end)
  end

  defp get_item_identifier(row, headers) do
    get_column(row, find_header_index(headers, "QTEGO #"))
  end

  defp get_position_within_item(row, rows_for_item) do
    Enum.find_index(rows_for_item, fn r -> r == row end) + 1
  end

  defp process_row(row, headers, csv_index, total, identifier, stats) do
    csv_raw_line = Enum.join(row, ",")
    csv_row_hash = hash_csv_row(csv_raw_line)

    item_identifier_str = get_item_identifier(row, headers)
    item_identifier = String.to_integer(item_identifier_str)

    {item, item_created} = find_or_create_item(item_identifier)

    stats =
      if item_created do
        %{
          stats
          | new_items: stats.new_items + 1,
            new_item_ids: MapSet.put(stats.new_item_ids, item_identifier)
        }
      else
        stats
      end

    existing_by_position =
      Repo.one(
        from(li in LineItem,
          where: li.item_id == ^item.id and li.identifier == ^identifier
        )
      )

    {stats, line_item_id} =
      cond do
        not is_nil(existing_by_position) and existing_by_position.csv_row_hash == csv_row_hash ->
          Mix.shell().info(
            "[#{csv_index}/#{total}] Skipped line item for ##{item_identifier} (unchanged)"
          )

          {%{stats | skipped: stats.skipped + 1}, existing_by_position.id}

        not is_nil(existing_by_position) ->
          attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id)
          changeset = LineItem.changeset(existing_by_position, attrs)
          {:ok, updated_item} = Repo.update(changeset)
          Mix.shell().info("[#{csv_index}/#{total}] Updated line item for ##{item_identifier}")

          {%{
             stats
             | updated: stats.updated + 1,
               updated_item_ids: MapSet.put(stats.updated_item_ids, item_identifier)
           }, updated_item.id}

        true ->
          attrs = build_attrs(row, headers, csv_row_hash, csv_raw_line, item.id)
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
  def is_placeholder_row?(row, headers) do
    item_id = get_item_identifier(row, headers)
    value = get_column(row, find_header_index(headers, "VALUE"))
    title = get_column(row, find_header_index(headers, "ITEM DONATED TITLE"))
    description = get_column(row, find_header_index(headers, "DETAILED ITEM DESCRIPTION"))

    item_id in ["", "0"] or value in ["", "0", "$0", "$0.00"] or title == "" or description == ""
  end

  @doc false
  def get_column(row, index) when is_integer(index) do
    row
    |> Enum.at(index, "")
    |> to_string()
    |> String.trim()
  end

  def get_column(_row, nil), do: ""

  @doc false
  def parse_value(value) do
    value
    |> String.replace(~r/[$,\s]/, "")
    |> String.split(".")
    |> List.first()
    |> case do
      "" -> ""
      num -> num
    end
  end

  @doc false
  def clean_title(title) do
    trimmed =
      title
      |> String.trim()
      |> String.replace(~r/\.\s*$/, "")

    # Capitalize first letter while preserving rest of the string
    case trimmed do
      "" ->
        ""

      <<first::utf8, rest::binary>> ->
        String.upcase(<<first::utf8>>) <> rest
    end
  end

  defp build_attrs(row, headers, csv_row_hash, csv_raw_line, item_id) do
    mappings = field_mappings()

    attrs =
      mappings
      |> Enum.reduce(%{}, fn {header, field_name}, acc ->
        if field_name == :item_identifier do
          acc
        else
          value =
            case find_header_index(headers, header) do
              nil -> ""
              index -> get_column(row, index)
            end

          normalized_value =
            case {field_name, value} do
              {:value, ""} -> nil
              {:value, val} -> parse_value(val)
              {:title, val} -> clean_title(val)
              _ -> value
            end

          Map.put(acc, field_name, normalized_value)
        end
      end)

    attrs
    |> Map.put(:item_id, item_id)
    |> Map.put(:csv_row_hash, csv_row_hash)
    |> Map.put(:csv_raw_line, csv_raw_line)
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
    empty_items =
      from(i in Item,
        left_join: li in assoc(i, :line_items),
        group_by: i.id,
        having: count(li.id) == 0,
        select: {i.id, i.item_identifier}
      )
      |> Repo.all()

    if length(empty_items) > 0 do
      Mix.shell().info("Deleting #{length(empty_items)} items with no line items...")

      empty_item_ids = Enum.map(empty_items, fn {id, _} -> id end)
      deleted_item_identifiers = Enum.map(empty_items, fn {_, identifier} -> identifier end)

      {deleted_count, _} =
        from(i in Item, where: i.id in ^empty_item_ids)
        |> Repo.delete_all()

      %{
        stats
        | deleted_items: deleted_count,
          deleted_item_ids:
            MapSet.union(stats.deleted_item_ids, MapSet.new(deleted_item_identifiers))
      }
    else
      stats
    end
  end
end
