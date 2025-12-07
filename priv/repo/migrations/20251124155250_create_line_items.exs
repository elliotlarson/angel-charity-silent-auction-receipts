defmodule Receipts.Repo.Migrations.CreateLineItems do
  use Ecto.Migration

  def change do
    create table(:line_items) do
      add :item_id, references(:items, on_delete: :delete_all), null: false
      add :identifier, :integer, null: false, default: 0
      add :title, :text, null: false, default: ""
      add :slug, :string, null: false, default: ""
      add :description, :text, null: false, default: ""
      add :value, :integer, null: false, default: 0
      add :categories, :text, null: false, default: ""
      add :notes, :text, null: false, default: ""
      add :expiration_notice, :text, null: false, default: ""
      add :csv_row_hash, :string, null: false
      add :csv_raw_line, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:line_items, [:item_id])
    create index(:line_items, [:csv_row_hash])
    create unique_index(:line_items, [:item_id, :identifier])
  end
end
