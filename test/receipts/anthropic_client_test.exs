defmodule Receipts.AnthropicClientTest do
  use ExUnit.Case

  alias Receipts.AnthropicClient

  describe "send_message/2" do
    test "returns error when API key is not configured" do
      Application.put_env(:receipts, :anthropic_api_key, nil)
      result = AnthropicClient.send_message("Test prompt")
      assert result == {:error, :missing_api_key}
    end

    test "returns error when API key is empty string" do
      Application.put_env(:receipts, :anthropic_api_key, "")
      result = AnthropicClient.send_message("Test prompt")
      assert result == {:error, :missing_api_key}
    end
  end
end
