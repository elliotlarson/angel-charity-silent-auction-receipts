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
- `db/auction_items/` - Data directory containing CSV and JSON files
  - `csv/` - Source CSV files with auction item data
  - `json/` - Processed JSON output files
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

Mix tasks for this project follow the pattern `mix task_name` and are used for processing auction item data (CSV to JSON conversion, data cleaning, field extraction).

## Elixir Version

This project uses Elixir ~> 1.19
