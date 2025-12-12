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
  end
end
