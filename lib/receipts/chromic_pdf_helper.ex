defmodule Receipts.ChromicPDFHelper do
  @moduledoc """
  Helper for managing ChromicPDF supervisor lifecycle.
  """

  @doc """
  Ensures ChromicPDF supervisor is started.

  Returns :ok if started successfully or already running.
  Raises if startup fails for reasons other than already_started.
  """
  def ensure_started do
    Application.ensure_all_started(:chromic_pdf)

    Process.flag(:trap_exit, true)

    case Supervisor.start_link([ChromicPDF], strategy: :one_for_one) do
      {:ok, _pid} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, {:shutdown, {:failed_to_start_child, ChromicPDF, {:already_started, _}}}} ->
        Process.flag(:trap_exit, false)
        :ok

      {:error, reason} ->
        Process.flag(:trap_exit, false)
        raise "Failed to start ChromicPDF: #{inspect(reason)}"
    end
  end
end
