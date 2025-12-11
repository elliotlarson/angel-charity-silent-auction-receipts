defmodule Mix.Tasks.SyncReceipts do
  use Mix.Task
  alias Receipts.Config

  @shortdoc "Sync PDF receipts to DropBox shared folder"

  @dropbox_dest "~/Dropbox/Projects/AngelCharity/2025_silent_auction_receipts/pdfs/"

  def run(_args) do
    source_dir = Config.pdf_dir()
    dest_dir = Path.expand(@dropbox_dest)

    unless File.dir?(source_dir) do
      Mix.shell().error("Error: Source directory does not exist: #{source_dir}")
      exit({:shutdown, 1})
    end

    unless File.dir?(dest_dir) do
      Mix.shell().error("Error: Destination directory does not exist: #{dest_dir}")
      Mix.shell().error("Please ensure DropBox is syncing and the folder exists.")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Syncing receipts from #{source_dir} to #{dest_dir}...")

    # Strip extended attributes before syncing to prevent Windows file type issues
    Mix.shell().info("Removing extended attributes from PDFs...")
    System.cmd("xattr", ["-cr", source_dir])

    case System.cmd("rsync", ["-av", "--delete", source_dir <> "/", dest_dir <> "/"]) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("Sync complete!")

      {output, code} ->
        Mix.shell().error("rsync failed with exit code #{code}")
        Mix.shell().error(output)
        exit({:shutdown, code})
    end
  end
end
