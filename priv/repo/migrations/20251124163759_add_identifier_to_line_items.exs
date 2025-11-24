defmodule Receipts.Repo.Migrations.AddIdentifierToLineItems do
  use Ecto.Migration

  def change do
    alter table(:line_items) do
      add :identifier, :string, null: false, default: "a"
    end

    # Update existing records to have unique identifiers per item
    execute("""
    WITH numbered_line_items AS (
      SELECT
        id,
        item_id,
        ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY id) - 1 AS row_num
      FROM line_items
    )
    UPDATE line_items
    SET identifier = CHAR(97 + (SELECT row_num FROM numbered_line_items WHERE numbered_line_items.id = line_items.id))
    """, "")

    create unique_index(:line_items, [:item_id, :identifier])
  end
end
