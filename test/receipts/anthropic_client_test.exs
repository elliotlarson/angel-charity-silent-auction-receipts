defmodule Receipts.AnthropicClientTest do
  use ExUnit.Case

  alias Receipts.AnthropicClient
  alias Receipts.Test.ApiFixtures

  setup do
    original_key = System.get_env("ANTHROPIC_API_KEY")

    on_exit(fn ->
      if original_key do
        System.put_env("ANTHROPIC_API_KEY", original_key)
      else
        System.delete_env("ANTHROPIC_API_KEY")
      end
    end)

    :ok
  end

  describe "send_message/2" do
    test "returns error when API key is not configured" do
      System.delete_env("ANTHROPIC_API_KEY")
      result = AnthropicClient.send_message("Test prompt")
      assert result == {:error, :missing_api_key}
    end

    test "returns error when API key is empty string" do
      System.put_env("ANTHROPIC_API_KEY", "")
      result = AnthropicClient.send_message("Test prompt")
      assert result == {:error, :missing_api_key}
    end

    test "returns success with text response from API" do
      System.put_env("ANTHROPIC_API_KEY", "test-key")
      http_client = ApiFixtures.mock_client("anthropic_success")

      result = AnthropicClient.send_message("Say hello", http_client: http_client)

      assert {:ok, text} = result
      assert text == "Hello! How can I help you today?"
    end

    test "returns api error on 401 unauthorized response" do
      System.put_env("ANTHROPIC_API_KEY", "invalid-key")
      http_client = ApiFixtures.mock_client("anthropic_401_error")

      result = AnthropicClient.send_message("Test prompt", http_client: http_client)

      assert {:error, {:api_error, 401, body}} = result
      assert body["error"]["type"] == "authentication_error"
      assert body["error"]["message"] == "invalid x-api-key"
    end

    test "returns network error on failed request" do
      System.put_env("ANTHROPIC_API_KEY", "test-key")

      http_client = fn _url, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end

      result = AnthropicClient.send_message("Test prompt", http_client: http_client)

      assert {:error, {:network_error, _reason}} = result
    end
  end
end
