defmodule Receipts.ProcessingCache do
  @moduledoc """
  Caches AI processing results to avoid redundant API calls.
  Cache is keyed by description hash.
  """

  alias Receipts.Config

  def get(description) do
    cache_key = hash_description(description)
    cache_path = Path.join(Config.cache_dir(), "#{cache_key}.json")

    case File.read(cache_path) do
      {:ok, content} -> Jason.decode(content, keys: :atoms)
      {:error, _} -> nil
    end
  end

  def put(description, result) do
    cache_key = hash_description(description)
    cache_path = Path.join(Config.cache_dir(), "#{cache_key}.json")

    File.mkdir_p!(Config.cache_dir())
    File.write!(cache_path, Jason.encode!(result))
  end

  defp hash_description(description) do
    :crypto.hash(:sha256, description)
    |> Base.encode16(case: :lower)
  end
end
