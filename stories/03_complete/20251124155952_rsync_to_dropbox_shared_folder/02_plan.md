# Implementation Plan: Rsync to DropBox Shared Folder

## Progress Checklist

- [x] Step 1: Add cleanup of orphan receipt files to generate_receipts task
- [x] Step 2: Add rsync script to sync PDFs to DropBox

## Overview

Create a shell script that syncs generated PDF receipts from `receipts/pdf/` to the shared DropBox folder at `~/Dropbox/Projects/AngelCharity/2025_silent_auction_receipts`. This enables a workflow where:
1. User receives new CSV data
2. Runs `mix process_auction_items` and `mix generate_receipts`
3. Runs the sync script to push PDFs to DropBox for collaborators

## Key Design Decisions

- **Cleanup before generate**: The generate_receipts task will clear orphan files (receipts for line items that no longer exist) before generating new ones
- **Location**: Script placed in `stories/.fais/scripts/` following project conventions for helper scripts
- **Tool**: Use `rsync` for efficient incremental syncing (only transfers changed files)
- **Flags**: Use `-av --delete` to mirror the source directory exactly, removing files from destination that no longer exist in source
- **No tests needed for script**: The shell script is simple with no application logic to test

## Implementation Steps

### Step 1: Add cleanup of orphan receipt files to generate_receipts task

**Files to modify:**
- `lib/mix/tasks/generate_receipts.ex`

**Changes:**

Add a cleanup step at the beginning of the task that:
1. Builds a set of expected filenames from line items in the database
2. Scans the pdf and html directories for existing files
3. Deletes any files that don't match expected filenames

```elixir
defp cleanup_orphan_files(line_items, pdf_dir, html_dir) do
  expected_basenames =
    line_items
    |> Enum.map(&LineItem.receipt_filename/1)
    |> MapSet.new()

  cleanup_directory(pdf_dir, expected_basenames, ".pdf")
  cleanup_directory(html_dir, expected_basenames, ".html")
end

defp cleanup_directory(dir, expected_basenames, extension) do
  case File.ls(dir) do
    {:ok, files} ->
      files
      |> Enum.filter(&String.ends_with?(&1, extension))
      |> Enum.reject(fn file ->
        basename = String.replace_suffix(file, extension, "")
        MapSet.member?(expected_basenames, basename)
      end)
      |> Enum.each(fn file ->
        path = Path.join(dir, file)
        Mix.shell().info("Removing orphan file: #{file}")
        File.rm!(path)
      end)

    {:error, :enoent} ->
      :ok
  end
end
```

Call `cleanup_orphan_files(line_items, pdf_dir, html_dir)` after querying line items and before generating receipts.

**Commit message:** `Add cleanup of orphan receipt files to generate_receipts task`

---

### Step 2: Add rsync script to sync PDFs to DropBox

**Files to create:**
- `stories/.fais/scripts/sync_receipts_to_dropbox.sh`

**Changes:**

Create a shell script that:
1. Uses rsync with archive mode (`-a`) for preserving permissions and recursive copy
2. Uses verbose mode (`-v`) to show what's being synced
3. Uses `--delete` to remove files from destination that no longer exist in source
4. Sources from `receipts/pdf/` relative to project root
5. Destinations to `~/Dropbox/Projects/AngelCharity/2025_silent_auction_receipts/`

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SOURCE_DIR="$PROJECT_ROOT/receipts/pdf/"
DEST_DIR="$HOME/Dropbox/Projects/AngelCharity/2025_silent_auction_receipts/"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory does not exist: $DEST_DIR"
    echo "Please ensure DropBox is syncing and the folder exists."
    exit 1
fi

rsync -av --delete "$SOURCE_DIR" "$DEST_DIR"

echo "Sync complete!"
```

**Commit message:** `Add script to sync PDF receipts to DropBox shared folder`
