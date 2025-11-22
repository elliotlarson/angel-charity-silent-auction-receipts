import Config

config :receipts,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
