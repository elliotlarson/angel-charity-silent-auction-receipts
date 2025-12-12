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
end
