defmodule Mix.Tasks.ProcessAuctionItems.CSV do
  NimbleCSV.define(Parser, separator: ",", escape: "\"")

  def decode(stream) do
    stream
    |> Parser.parse_stream()
  end
end
