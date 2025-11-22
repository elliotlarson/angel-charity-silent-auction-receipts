defmodule Receipts.AIDescriptionProcessorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Receipts.AIDescriptionProcessor

  describe "process/2" do
    test "returns attrs unchanged when skip_ai_processing is true" do
      attrs = %{
        item_id: "123",
        description: "Test description with expiration info"
      }

      result = AIDescriptionProcessor.process(attrs, skip_ai_processing: true)
      assert result == attrs
    end

    test "returns attrs unchanged when description is empty" do
      attrs = %{item_id: "123", description: ""}
      result = AIDescriptionProcessor.process(attrs)
      assert result == attrs
    end

    test "logs warning and returns original attrs when API call fails" do
      Application.put_env(:receipts, :anthropic_api_key, nil)

      attrs = %{
        item_id: "123",
        description: "Test description"
      }

      log =
        capture_log(fn ->
          result = AIDescriptionProcessor.process(attrs)
          assert result == attrs
        end)

      assert log =~ "Failed to process description"
      assert log =~ "item 123"
    end
  end
end
