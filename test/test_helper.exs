Code.require_file("support/api_fixtures_helper.exs", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Receipts.Repo, :manual)

# Configure ChromicPDF with longer timeouts for CI environments
# and disable sandbox for Docker/CI environments
chromic_config = [
  {ChromicPDF,
   [
     chrome_args: "--no-sandbox --disable-gpu --disable-dev-shm-usage",
     session_pool: [
       init_timeout: String.to_integer(System.get_env("CHROMIC_PDF_INIT_TIMEOUT") || "5000"),
       timeout: String.to_integer(System.get_env("CHROMIC_PDF_TIMEOUT") || "5000"),
       checkout_timeout:
         String.to_integer(System.get_env("CHROMIC_PDF_CHECKOUT_TIMEOUT") || "5000"),
       size: 2
     ]
   ]}
]

{:ok, _} = Supervisor.start_link(chromic_config, strategy: :one_for_one, name: Test.Supervisor)
