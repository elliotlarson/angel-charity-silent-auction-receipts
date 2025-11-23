defmodule Receipts.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Receipts.Repo
    ]

    opts = [strategy: :one_for_one, name: Receipts.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
