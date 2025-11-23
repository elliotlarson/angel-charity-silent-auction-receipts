defmodule Receipts.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Receipts.Repo
      import Ecto
      import Ecto.Query
      import Receipts.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Receipts.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Receipts.Repo, {:shared, self()})
    end

    :ok
  end
end
