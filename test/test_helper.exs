Code.require_file("support/api_fixtures.ex", __DIR__)

ExUnit.start()

{:ok, _} = Supervisor.start_link([ChromicPDF], strategy: :one_for_one, name: Test.Supervisor)
