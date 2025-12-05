defmodule Mix.Tasks.MigrateJsonToDb do
  use Mix.Task

  alias Receipts.Item
  alias Receipts.LineItem
  alias Receipts.Config
  alias Receipts.Repo

  NimbleCSV.define(MigrationCSVParser, separator: ",", escape: "\"")

  @shortdoc "One-time migration: Import JSON files to database"

  @moduledoc """
  Imports existing JSON files into the database with actual CSV row hashes.
  This is a one-time migration task.

  For each JSON file, finds the corresponding CSV file and computes the actual
  CSV row hash for change detection.

  ## Usage

      mix migrate_json_to_db
  """

  def run(_args) do
    Application.ensure_all_started(:receipts)

    json_dir = Config.json_dir()
    csv_dir = Config.csv_dir()

    json_files =
      case File.ls(json_dir) do
        {:ok, files} ->
          Enum.filter(files, &String.ends_with?(&1, ".json"))

        {:error, _} ->
          []
      end

    if json_files == [] do
      Mix.shell().error("No JSON files found in #{json_dir}")
      System.halt(1)
    end

    Mix.shell().info("Importing #{length(json_files)} JSON file(s) to database...")
    Mix.shell().info("CSV files will be read to compute correct hashes for change detection.\n")

    import_files(json_files, json_dir, csv_dir)
  end

  defp import_files(files, json_dir, csv_dir) do
    stats = %{items_created: 0, line_items_imported: 0, skipped: 0, no_csv: 0}

    final_stats =
      Enum.reduce(files, stats, fn filename, acc ->
        Mix.shell().info("\nProcessing #{filename}...")

        csv_filename = String.replace_suffix(filename, ".json", ".csv")
        csv_path = Path.join(csv_dir, csv_filename)

        csv_row_map =
          if File.exists?(csv_path) do
            map = build_csv_row_map(csv_path)
            Mix.shell().info("  Found CSV file with #{map_size(map)} rows")
            map
          else
            Mix.shell().info(
              "  Warning: CSV file #{csv_filename} not found, using placeholder hashes"
            )

            %{}
          end

        json_path = Path.join(json_dir, filename)
        {:ok, content} = File.read(json_path)
        {:ok, items_data} = Jason.decode(content)

        Enum.reduce(items_data, acc, fn item_data, acc_inner ->
          item_identifier = item_data["item_id"]

          # Find or create Item
          {item, item_created} = find_or_create_item(item_identifier)

          acc_inner =
            if item_created,
              do: %{acc_inner | items_created: acc_inner.items_created + 1},
              else: acc_inner

          {csv_row_hash, csv_raw_line} =
            case Map.get(csv_row_map, item_identifier) do
              nil -> {"migrated_from_json", "migrated_from_json"}
              entries when is_list(entries) -> hd(entries)
            end

          attrs =
            item_data
            |> Map.put("item_id", item.id)
            |> Map.put("csv_row_hash", csv_row_hash)
            |> Map.put("csv_raw_line", csv_raw_line)

          # Check if line item already exists
          case Repo.get_by(LineItem, item_id: item.id, csv_row_hash: csv_row_hash) do
            nil ->
              identifier = LineItem.next_identifier(item.id)
              attrs_with_identifier = Map.put(attrs, "identifier", identifier)

              %LineItem{}
              |> LineItem.changeset(attrs_with_identifier)
              |> Repo.insert!()

              new_acc = %{acc_inner | line_items_imported: acc_inner.line_items_imported + 1}

              if csv_row_hash == "migrated_from_json" do
                %{new_acc | no_csv: new_acc.no_csv + 1}
              else
                new_acc
              end

            _existing ->
              Mix.shell().info("  Skipped line item for ##{item_identifier} (already exists)")
              %{acc_inner | skipped: acc_inner.skipped + 1}
          end
        end)
      end)

    Mix.shell().info("\nMigration complete!")
    Mix.shell().info("Items created: #{final_stats.items_created}")
    Mix.shell().info("Line items imported: #{final_stats.line_items_imported}")
    Mix.shell().info("Skipped: #{final_stats.skipped} (already in database)")

    if final_stats.no_csv > 0 do
      Mix.shell().info("Warning: #{final_stats.no_csv} items imported without CSV hash")
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

  defp build_csv_row_map(csv_path) do
    # Build map of item_identifier => [{hash, raw_line}, ...] to handle duplicates
    rows =
      csv_path
      |> File.stream!()
      |> MigrationCSVParser.parse_stream()
      |> Enum.to_list()

    case rows do
      [_title_row, headers, _empty_row | data_rows] ->
        item_id_index =
          headers
          |> Enum.find_index(fn header ->
            String.upcase(String.trim(header)) == "ITEM ID"
          end)

        if is_nil(item_id_index) do
          Mix.shell().info("  Warning: ITEM ID column not found in CSV headers")
          %{}
        else
          Enum.reduce(data_rows, %{}, fn row, acc ->
            csv_raw_line = Enum.join(row, ",")
            csv_row_hash = hash_csv_row(csv_raw_line)

            item_id_str =
              row
              |> Enum.at(item_id_index, "")
              |> to_string()
              |> String.trim()

            case Integer.parse(item_id_str) do
              {item_id, _} when item_id > 0 ->
                existing = Map.get(acc, item_id, [])
                Map.put(acc, item_id, [{csv_row_hash, csv_raw_line} | existing])

              _ ->
                acc
            end
          end)
        end

      _ ->
        Mix.shell().info("  Warning: CSV file format unexpected")
        %{}
    end
  end

  defp hash_csv_row(csv_line) do
    :crypto.hash(:sha256, csv_line)
    |> Base.encode16(case: :lower)
  end
end
