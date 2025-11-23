Code.require_file("support/api_fixtures_helper.exs", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Receipts.Repo, :manual)

{:ok, _} = Supervisor.start_link([ChromicPDF], strategy: :one_for_one, name: Test.Supervisor)
