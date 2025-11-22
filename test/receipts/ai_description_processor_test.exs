defmodule Receipts.AIDescriptionProcessorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Receipts.AIDescriptionProcessor

  describe "process/2" do
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
      System.delete_env("ANTHROPIC_API_KEY")

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
