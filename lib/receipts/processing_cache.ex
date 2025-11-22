defmodule Receipts.ProcessingCache do
  @moduledoc """
  Caches AI processing results to avoid redundant API calls.
  Cache is keyed by description hash.
  """

  @cache_dir "db/auction_items/cache"

  def get(description) do
    cache_key = hash_description(description)
    cache_path = Path.join(@cache_dir, "#{cache_key}.json")

    case File.read(cache_path) do
      {:ok, content} -> Jason.decode(content)
      {:error, _} -> nil
    end
  end

  def put(description, result) do
    cache_key = hash_description(description)
    cache_path = Path.join(@cache_dir, "#{cache_key}.json")

    File.mkdir_p!(@cache_dir)
    File.write!(cache_path, Jason.encode!(result))
  end

  defp hash_description(description) do
    :crypto.hash(:sha256, description)
    |> Base.encode16(case: :lower)
  end
end
