# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir project called "Receipts" for processing auction item data from CSV files. The project uses the `fais` (Framework for AI-Structured Development) tool for markdown-based story management with AI assistants.

## Commands

### Development

- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test test/path/to/test.exs` - Run a specific test file
- `mix test test/path/to/test.exs:42` - Run a specific test at line 42
- `mix format` - Format code according to .formatter.exs
- `mix format --check-formatted` - Check if code is formatted
- `mix generate_combined_pdf <item_ids>` - Generate combined PDF for specified item IDs (comma-delimited)

### Dependencies

- `mix deps.get` - Fetch dependencies
- `mix deps.compile` - Compile dependencies

### Story Management (fais)

- `fais story "Title"` - Create a new story in the backlog
- `fais job` - Interactively select a story and job to run with AI
- `fais move` - Move a story between backlog/working/complete

## Architecture

### Project Structure

- `lib/` - Application code
- `test/` - Test files (\*.exs)
- `db/` - Data directory
  - `auction_items_source_data/` - Source CSV files with auction item data
  - `receipts_dev.db` - SQLite database (source of truth for auction items)
  - `receipts_test.db` - SQLite test database
- `receipts/` - Generated output files
  - `pdf/` - Generated PDF receipts
  - `html/` - Generated HTML receipts
- `stories/` - fais story management directories
  - `01_backlog/` - Stories not yet started
  - `02_working/` - Stories in progress
  - `03_complete/` - Finished stories
  - `.fais/` - Templates, jobs, context, and scripts for fais

### fais Workflow Integration

This project uses fais for AI-assisted development. When running `fais job`, all context files in `stories/.fais/context/` are automatically loaded to provide project-specific information. Story directories are timestamped and contain:

- `01_story.md` - Feature description
- `02_plan.md` - Implementation plan with progress checklists
- `03_acceptance.md` - Acceptance criteria

Each implementation step should be presented for approval before committing.

### Mix Tasks

Mix tasks for this project follow the pattern `mix task_name` and are used for processing auction item data:

- `mix process_auction_items` - Process CSV files and save to database with change detection
- `mix generate_receipts` - Generate PDF and HTML receipts for all items from database, plus a combined PDF (combined_receipts.pdf)
- `mix generate_receipt <item_id>` - Generate fresh HTML and PDF for one item from database
- `mix regenerate_receipt_pdf <item_id>` - Regenerate PDF from existing edited HTML
- `mix generate_combined_pdf <item_ids>` - Generate combined PDF for specified item IDs (e.g., `mix generate_combined_pdf 101,103,105`)
- `mix migrate_json_to_db` - One-time migration from JSON files to database

### Database

The project uses Ecto with SQLite3 for data persistence:

- `Receipts.Repo` - Ecto repository for database access
- `Receipts.AuctionItem` - Schema for auction items with change detection fields
- Change detection via SHA256 hashing of CSV rows
- Migrations in `priv/repo/migrations/`

## Elixir Version

This project uses Elixir ~> 1.19
