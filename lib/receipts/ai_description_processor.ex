defmodule Receipts.AIDescriptionProcessor do
  @moduledoc """
  Processes auction item descriptions using AI to extract
  expiration notices and special notes.
  """

  alias Receipts.AnthropicClient
  alias Receipts.ProcessingCache
  alias Receipts.TextNormalizer
  require Logger

  @doc """
  Processes auction item attributes to extract fields from description.

  ## Options
    * `:skip_ai_processing` - Skip AI processing (default: false)

  ## Returns
  Updated attributes map with extracted fields
  """
  def process(attrs, opts \\ []) do
    skip_processing = Keyword.get(opts, :skip_ai_processing, false)
    description = Map.get(attrs, :description, "")

    if skip_processing or description == "" do
      attrs
    else
      process_with_ai(attrs, description)
    end
  end

  defp process_with_ai(attrs, description) do
    case ProcessingCache.get(description) do
      nil ->
        process_and_cache(attrs, description)

      {:ok, cached_result} ->
        Logger.debug("Using cached result for item #{attrs[:item_id]}")
        apply_extraction(attrs, cached_result)

      _ ->
        process_and_cache(attrs, description)
    end
  end

  defp process_and_cache(attrs, description) do
    prompt = build_prompt(description)

    case AnthropicClient.send_message(prompt) do
      {:ok, response_text} ->
        case parse_response(response_text) do
          {:ok, extracted} ->
            Logger.debug("AI processed item #{attrs[:item_id]}")
            ProcessingCache.put(description, extracted)
            apply_extraction(attrs, extracted)

          {:error, reason} ->
            Logger.warning(
              "Failed to parse response for item #{attrs[:item_id]}: #{inspect(reason)}"
            )

            attrs
        end

      {:error, reason} ->
        Logger.warning(
          "Failed to process description for item #{attrs[:item_id]}: #{inspect(reason)}"
        )

        attrs
    end
  end

  defp build_prompt(description) do
    """
    Analyze the following auction item description and extract any expiration dates/notices and special notes/instructions.

    Description: #{description}

    Please respond with ONLY a JSON object in this exact format (no markdown, no extra text):
    {
      "expiration_notice": "extracted expiration info or empty string",
      "notes": "extracted special notes/instructions or empty string",
      "description": "the description with expiration and notes removed"
    }

    Guidelines:
    - expiration_notice: Any text about expiration dates, validity periods, or time limits
    - notes: Special instructions like "call ahead", "out of town charges apply", "schedule with...", contact info, restrictions
    - description: The original description minus the extracted content
    - Use empty strings "" if nothing to extract
    - Keep the description clean and focused on describing the item itself
    """
  end

  defp parse_response(response_text) do
    # Try to extract JSON from markdown code blocks if present
    cleaned_text =
      case Regex.run(~r/```(?:json)?\s*(\{.*?\})\s*```/s, response_text) do
        [_, json] -> json
        nil -> response_text
      end
      |> String.trim()

    case Jason.decode(cleaned_text) do
      {:ok, %{"expiration_notice" => exp, "notes" => notes, "description" => desc}} ->
        {:ok, %{expiration_notice: exp, notes: notes, description: desc}}

      {:ok, parsed} ->
        Logger.warning("Unexpected JSON structure: #{inspect(parsed)}")
        {:error, :invalid_response_format}

      {:error, reason} ->
        Logger.warning("Failed to parse JSON: #{inspect(reason)}. Response: #{String.slice(response_text, 0..200)}")
        {:error, :invalid_response_format}
    end
  end

  defp apply_extraction(attrs, %{expiration_notice: exp, notes: notes, description: clean_desc}) do
    attrs
    |> put_if_present(:expiration_notice, TextNormalizer.normalize(exp))
    |> put_if_present(:notes, TextNormalizer.normalize(notes))
    |> put_if_present(:description, TextNormalizer.normalize(clean_desc))
  end

  defp put_if_present(attrs, _key, ""), do: attrs
  defp put_if_present(attrs, key, value), do: Map.put(attrs, key, value)
end
