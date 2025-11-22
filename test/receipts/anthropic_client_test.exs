defmodule Receipts.AnthropicClientTest do
  use ExUnit.Case

  alias Receipts.AnthropicClient

  describe "send_message/2" do
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
  end
end
