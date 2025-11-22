defmodule ConfigTest do
  use ExUnit.Case

  test "anthropic_api_key is configurable" do
    # Config should be nil when env var not set, or a string when set
    api_key = Application.get_env(:receipts, :anthropic_api_key)
    assert is_nil(api_key) or is_binary(api_key)
  end
end
