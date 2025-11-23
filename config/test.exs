import Config

config :receipts, Receipts.Repo,
  database: "db/receipts_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false

config :logger, level: :warning
