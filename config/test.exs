import Config

config :receipts, Receipts.Repo,
  database: "db/receipts_test.db",
  pool: Ecto.Adapters.SQL.Sandbox
