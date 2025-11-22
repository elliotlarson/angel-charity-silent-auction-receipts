ExUnit.start()

{:ok, _} = Supervisor.start_link([ChromicPDF], strategy: :one_for_one, name: Test.Supervisor)
