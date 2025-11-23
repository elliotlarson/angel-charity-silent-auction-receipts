import Config

config :receipts, Receipts.Repo,
  database: "receipts_test.db",
  pool: Ecto.Adapters.SQL.Sandbox
