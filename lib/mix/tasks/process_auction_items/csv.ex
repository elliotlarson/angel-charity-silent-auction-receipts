defmodule Mix.Tasks.ProcessAuctionItems.CSV do
  def decode(stream) do
    stream
    |> Stream.map(&parse_line/1)
  end

  defp parse_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end
end
