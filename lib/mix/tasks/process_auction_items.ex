defmodule Mix.Tasks.ProcessAuctionItems do
  use Mix.Task

  @shortdoc "Process auction items CSV files and convert to JSON"

  @csv_dir "db/auction_items/csv"

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
    Mix.shell().info("Processing #{filename}...")
  end
end
