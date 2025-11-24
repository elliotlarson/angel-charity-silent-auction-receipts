defmodule Receipts.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :item_identifier, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:items, [:item_identifier])
  end
end
