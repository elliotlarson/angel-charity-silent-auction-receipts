defmodule Receipts.AnthropicClient do
  @moduledoc """
  Generic client for interacting with the Anthropic API.
  Handles authentication and message sending/receiving.
  """

  @api_base_url "https://api.anthropic.com/v1"
  @default_model "claude-sonnet-4-5-20250929"
  @api_version "2023-06-01"

  @doc """
  Sends a message to Claude and returns the text response.

  ## Options
    * `:model` - The Claude model to use (default: #{@default_model})
    * `:max_tokens` - Maximum tokens in response (default: 1024)

  ## Returns
    * `{:ok, response_text}` - On success
    * `{:error, reason}` - On failure
  """
  def send_message(prompt, opts \\ []) do
    api_key = Application.get_env(:receipts, :anthropic_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      model = Keyword.get(opts, :model, @default_model)
      max_tokens = Keyword.get(opts, :max_tokens, 1024)
      make_request(prompt, api_key, model, max_tokens)
    end
  end

  defp make_request(prompt, api_key, model, max_tokens) do
    request_body = %{
      model: model,
      max_tokens: max_tokens,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ]
    }

    response =
      Req.post!(
        "#{@api_base_url}/messages",
        json: request_body,
        headers: [
          {"x-api-key", api_key},
          {"anthropic-version", @api_version},
          {"content-type", "application/json"}
        ]
      )

    parse_response(response)
  end

  defp parse_response(%{status: 200, body: body}) do
    case body do
      %{"content" => [%{"text" => text} | _]} ->
        {:ok, text}

      _ ->
        {:error, :unexpected_response_structure}
    end
  end

  defp parse_response(%{status: status, body: body}) do
    {:error, {:api_error, status, body}}
  end
end
