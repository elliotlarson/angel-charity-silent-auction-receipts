defmodule Receipts.Repo.Migrations.RemoveItemIdentifierFromLineItems do
  use Ecto.Migration

  def change do
    drop index(:line_items, [:item_identifier])

    alter table(:line_items) do
      remove :item_identifier
    end
  end
end
