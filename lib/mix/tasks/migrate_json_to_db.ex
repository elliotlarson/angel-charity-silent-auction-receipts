defmodule Mix.Tasks.MigrateJsonToDb do
  use Mix.Task

  alias Receipts.AuctionItem
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
    stats = %{imported: 0, skipped: 0, no_csv: 0}

    final_stats =
      Enum.reduce(files, stats, fn filename, acc ->
        Mix.shell().info("\nProcessing #{filename}...")

        # Find corresponding CSV file
        csv_filename = String.replace_suffix(filename, ".json", ".csv")
        csv_path = Path.join(csv_dir, csv_filename)

        csv_row_map =
          if File.exists?(csv_path) do
            map = build_csv_row_map(csv_path)
            Mix.shell().info("  Found CSV file with #{map_size(map)} items")
            map
          else
            Mix.shell().info("  Warning: CSV file #{csv_filename} not found, using placeholder hashes")
            %{}
          end

        # Load JSON items
        json_path = Path.join(json_dir, filename)
        {:ok, content} = File.read(json_path)
        {:ok, items_data} = Jason.decode(content)

        Enum.reduce(items_data, acc, fn item_data, acc_inner ->
          item_id = item_data["item_id"]

          {csv_row_hash, csv_raw_line} =
            case Map.get(csv_row_map, item_id) do
              {hash, raw_line} ->
                {hash, raw_line}
              nil ->
                # CSV not found or item not in CSV - use placeholder
                {"migrated_from_json", "migrated_from_json"}
            end

          attrs =
            item_data
            |> Map.put("csv_row_hash", csv_row_hash)
            |> Map.put("csv_raw_line", csv_raw_line)

          case Repo.get_by(AuctionItem, item_id: attrs["item_id"]) do
            nil ->
              %AuctionItem{}
              |> AuctionItem.changeset(attrs)
              |> Repo.insert!()

              new_acc = %{acc_inner | imported: acc_inner.imported + 1}
              if csv_row_hash == "migrated_from_json" do
                %{new_acc | no_csv: new_acc.no_csv + 1}
              else
                new_acc
              end

            _existing ->
              Mix.shell().info("  Skipped item ##{attrs["item_id"]} (already exists)")
              %{acc_inner | skipped: acc_inner.skipped + 1}
          end
        end)
      end)

    Mix.shell().info("\nMigration complete!")
    Mix.shell().info("Imported: #{final_stats.imported} items")
    Mix.shell().info("Skipped: #{final_stats.skipped} items (already in database)")

    if final_stats.no_csv > 0 do
      Mix.shell().info("Warning: #{final_stats.no_csv} items imported without CSV hash (will be updated on next CSV processing)")
    end
  end

  defp build_csv_row_map(csv_path) do
    rows =
      csv_path
      |> File.stream!()
      |> MigrationCSVParser.parse_stream()
      |> Enum.to_list()

    case rows do
      [_title_row, headers, _empty_row | data_rows] ->
        # Find item_id column index
        item_id_index =
          headers
          |> Enum.find_index(fn header ->
            String.upcase(String.trim(header)) == "ITEM ID"
          end)

        if is_nil(item_id_index) do
          Mix.shell().info("  Warning: ITEM ID column not found in CSV headers")
          %{}
        else
          # Build map of item_id => {hash, raw_line}
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
                Map.put(acc, item_id, {csv_row_hash, csv_raw_line})

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
