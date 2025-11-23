defmodule Receipts.ConfigTest do
  use ExUnit.Case

  alias Receipts.Config

  describe "default configuration" do
    test "csv_dir returns default path" do
      assert Config.csv_dir() == "db/auction_items_source_data"
    end

    test "json_dir returns default path" do
      assert Config.json_dir() == "db/auction_items_source_data"
    end

    test "pdf_dir returns default path" do
      assert Config.pdf_dir() == "receipts/pdf"
    end

    test "html_dir returns default path" do
      assert Config.html_dir() == "receipts/html"
    end

    test "cache_dir returns default path" do
      assert Config.cache_dir() == "db/auction_items_source_data/cache"
    end

    test "template_path returns default path" do
      assert Config.template_path() == "priv/templates/receipt.html.eex"
    end

    test "logo_path returns default path" do
      assert Config.logo_path() == "priv/static/angel_charity_logo.svg"
    end
  end

  describe "configuration override" do
    setup do
      original = Application.get_env(:receipts, :csv_dir)

      on_exit(fn ->
        if original do
          Application.put_env(:receipts, :csv_dir, original)
        else
          Application.delete_env(:receipts, :csv_dir)
        end
      end)

      :ok
    end

    test "respects application environment config" do
      Application.put_env(:receipts, :csv_dir, "custom/csv/path")
      assert Config.csv_dir() == "custom/csv/path"
    end
  end

  describe "database configuration" do
    test "database configuration is present" do
      config = Application.get_env(:receipts, Receipts.Repo)
      assert config[:database] =~ "db/receipts_"
      assert config[:pool_size] == 5
    end

    test "ecto_repos includes Receipts.Repo" do
      repos = Application.get_env(:receipts, :ecto_repos)
      assert Receipts.Repo in repos
    end
  end
end
