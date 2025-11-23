defmodule Receipts.Repo.Migrations.CreateAuctionItems do
  use Ecto.Migration

  def change do
    create table(:auction_items) do
      add :item_id, :integer, null: false
      add :short_title, :text, null: false, default: ""
      add :title, :text, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :fair_market_value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""

      # Change detection and audit fields
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:auction_items, [:item_id])
    create index(:auction_items, [:csv_row_hash])
  end
end
