defmodule Receipts do
  @moduledoc """
  Receipts is an Elixir application for processing auction item data and generating receipts.

  ## Main Components

  - `Receipts.AuctionItem` - Data model for auction items with validation
  - `Receipts.ReceiptGenerator` - Generates PDF and HTML receipts
  - `Receipts.AIDescriptionProcessor` - Extracts metadata using AI
  - `Receipts.ProcessingCache` - Caches AI processing results
  - `Receipts.Config` - Centralized configuration management
  - `Receipts.ChromicPDFHelper` - ChromicPDF supervisor management

  ## Mix Tasks

  - `mix process_auction_items` - Convert CSV files to JSON
  - `mix generate_receipts` - Generate PDF/HTML receipts from JSON
  - `mix regenerate_receipt <item_id>` - Regenerate single receipt from edited HTML

  ## Usage

  Process a CSV file:

      mix process_auction_items

  Generate receipts for all items:

      mix generate_receipts

  Regenerate a single receipt after editing HTML:

      mix regenerate_receipt 120
  """
end
