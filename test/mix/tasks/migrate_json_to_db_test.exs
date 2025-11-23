defmodule Mix.Tasks.MigrateJsonToDbTest do
  use Receipts.DataCase
  import ExUnit.CaptureIO

  alias Receipts.AuctionItem
  alias Receipts.Repo

  @test_json_dir "test/tmp/json"
  @test_csv_dir "test/tmp/csv"

  setup do
    File.mkdir_p!(@test_json_dir)
    File.mkdir_p!(@test_csv_dir)

    original_json_dir = Application.get_env(:receipts, :json_dir)
    original_csv_dir = Application.get_env(:receipts, :csv_dir)

    Application.put_env(:receipts, :json_dir, @test_json_dir)
    Application.put_env(:receipts, :csv_dir, @test_csv_dir)

    on_exit(fn ->
      File.rm_rf!("test/tmp")

      if original_json_dir do
        Application.put_env(:receipts, :json_dir, original_json_dir)
      else
        Application.delete_env(:receipts, :json_dir)
      end

      if original_csv_dir do
        Application.put_env(:receipts, :csv_dir, original_csv_dir)
      else
        Application.delete_env(:receipts, :csv_dir)
      end
    end)

    :ok
  end

  test "imports JSON files with CSV row hashes when CSV file exists" do
    # Create matching CSV file with format matching actual CSV files
    csv_content = """
    ,Angel Charity Foundation,,,,,
    ,,,,,
    ITEM ID,15 CHARACTER DESCRIPTION,100 CHARACTER DESCRIPTION,1500 CHARACTER DESCRIPTION (OPTIONAL),FAIR MARKET VALUE,CATEGORIES (OPTIONAL)
    ,,,,,
    1,Test,Test Item,Test description,100,TEST
    """

    csv_path = Path.join(@test_csv_dir, "test.csv")
    File.write!(csv_path, csv_content)

    # Create JSON file
    test_data = [
      %{
        "item_id" => 1,
        "short_title" => "Test",
        "title" => "Test Item",
        "description" => "Test description",
        "fair_market_value" => 100,
        "categories" => "TEST",
        "notes" => "Test notes",
        "expiration_notice" => "No expiration"
      }
    ]

    json_path = Path.join(@test_json_dir, "test.json")
    File.write!(json_path, Jason.encode!(test_data))

    # Run migration
    output =
      capture_io(fn ->
        Mix.Tasks.MigrateJsonToDb.run([])
      end)

    assert output =~ "Importing 1 JSON file(s)"
    assert output =~ "Processing test.json"
    assert output =~ "Migration complete!"
    assert output =~ "Imported: 1 items"
    assert output =~ "Skipped: 0 items"

    # Verify item was imported with actual CSV hash
    item = Repo.get_by(AuctionItem, item_id: 1)
    assert item.title == "Test Item"
    assert item.csv_raw_line == "1,Test,Test Item,Test description,100,TEST"
    assert item.csv_row_hash != "migrated_from_json"
    assert String.length(item.csv_row_hash) == 64
  end

  test "imports JSON files with placeholder hash when CSV file missing" do
    # Create JSON file without corresponding CSV
    test_data = [
      %{
        "item_id" => 1,
        "short_title" => "Test",
        "title" => "Test Item",
        "description" => "Test description",
        "fair_market_value" => 100,
        "categories" => "TEST",
        "notes" => "Test notes",
        "expiration_notice" => "No expiration"
      }
    ]

    json_path = Path.join(@test_json_dir, "test.json")
    File.write!(json_path, Jason.encode!(test_data))

    # Run migration
    output =
      capture_io(fn ->
        Mix.Tasks.MigrateJsonToDb.run([])
      end)

    assert output =~ "Warning: CSV file test.csv not found"
    assert output =~ "Imported: 1 items"
    assert output =~ "Warning: 1 items imported without CSV hash"

    # Verify item was imported with placeholder
    item = Repo.get_by(AuctionItem, item_id: 1)
    assert item.title == "Test Item"
    assert item.csv_raw_line == "migrated_from_json"
    assert item.csv_row_hash == "migrated_from_json"
  end

  test "skips items that already exist in database" do
    # Create CSV file
    csv_content = """
    ,Angel Charity Foundation,,,,,
    ,,,,,
    ITEM ID,15 CHARACTER DESCRIPTION,100 CHARACTER DESCRIPTION,1500 CHARACTER DESCRIPTION (OPTIONAL),FAIR MARKET VALUE,CATEGORIES (OPTIONAL)
    ,,,,,
    1,Test,Test Item,Test description,100,TEST
    """

    csv_path = Path.join(@test_csv_dir, "test.csv")
    File.write!(csv_path, csv_content)

    # Insert an item first
    Repo.insert!(%AuctionItem{
      item_id: 1,
      title: "Existing Item",
      short_title: "Existing",
      description: "Existing description",
      fair_market_value: 100,
      categories: "",
      notes: "",
      expiration_notice: "",
      csv_row_hash: "existing_hash",
      csv_raw_line: "existing,line"
    })

    # Create JSON with same item_id
    test_data = [
      %{
        "item_id" => 1,
        "short_title" => "Test",
        "title" => "Test Item",
        "description" => "Test description",
        "fair_market_value" => 100,
        "categories" => "TEST",
        "notes" => "Test notes",
        "expiration_notice" => "No expiration"
      }
    ]

    json_path = Path.join(@test_json_dir, "test.json")
    File.write!(json_path, Jason.encode!(test_data))

    # Run migration
    output =
      capture_io(fn ->
        Mix.Tasks.MigrateJsonToDb.run([])
      end)

    assert output =~ "Skipped item #1 (already exists)"
    assert output =~ "Imported: 0 items"
    assert output =~ "Skipped: 1 items"

    # Verify original item unchanged
    item = Repo.get_by(AuctionItem, item_id: 1)
    assert item.title == "Existing Item"
  end

end
