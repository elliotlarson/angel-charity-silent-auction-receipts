import Config

config :receipts, Receipts.Repo,
  database: "db/receipts_#{config_env()}.db",
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :receipts, ecto_repos: [Receipts.Repo]

import_config "#{config_env()}.exs"
