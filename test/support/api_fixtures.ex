defmodule Receipts.Test.ApiFixtures do
  @moduledoc """
  Loads API response fixtures for testing without making real HTTP calls.
  """

  @fixtures_dir "test/fixtures"

  @doc """
  Creates a mock HTTP client that returns the specified fixture response.

  ## Examples

      http_client = ApiFixtures.mock_client("anthropic_success")
      AnthropicClient.send_message("test", http_client: http_client)
  """
  def mock_client(fixture_name) do
    fn _url, _opts ->
      fixture_path = Path.join(@fixtures_dir, "#{fixture_name}.json")
      {:ok, content} = File.read(fixture_path)
      {:ok, response} = Jason.decode(content)

      {:ok, %{status: response["status"], body: response["body"]}}
    end
  end
end
