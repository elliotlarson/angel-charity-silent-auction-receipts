defmodule Receipts.Config do
  @moduledoc """
  Centralized configuration for the Receipts application.
  All file paths and configurable values are managed here.
  """

  @doc "Directory containing CSV input files"
  def csv_dir, do: get_env(:csv_dir, "db/auction_items/csv")

  @doc "Directory containing JSON output files"
  def json_dir, do: get_env(:json_dir, "db/auction_items/json")

  @doc "Directory for generated PDF receipts"
  def pdf_dir, do: get_env(:pdf_dir, "receipts/pdf")

  @doc "Directory for generated HTML receipts"
  def html_dir, do: get_env(:html_dir, "receipts/html")

  @doc "Directory for AI processing cache"
  def cache_dir, do: get_env(:cache_dir, "db/auction_items/cache")

  @doc "Path to receipt HTML template"
  def template_path, do: get_env(:template_path, "priv/templates/receipt.html.eex")

  @doc "Path to logo file"
  def logo_path, do: get_env(:logo_path, "priv/static/angel_charity_logo.svg")

  defp get_env(key, default) do
    Application.get_env(:receipts, key, default)
  end
end
