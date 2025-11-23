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
    * `:http_client` - HTTP client function for testing (default: uses Req)

  ## Returns
    * `{:ok, response_text}` - On success
    * `{:error, reason}` - On failure
  """
  def send_message(prompt, opts \\ []) do
    api_key = System.get_env("ANTHROPIC_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      model = Keyword.get(opts, :model, @default_model)
      max_tokens = Keyword.get(opts, :max_tokens, 1024)
      http_client = Keyword.get(opts, :http_client, &Req.post/2)
      make_request(prompt, api_key, model, max_tokens, http_client)
    end
  end

  defp make_request(prompt, api_key, model, max_tokens, http_client) do
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

    case http_client.(
           "#{@api_base_url}/messages",
           json: request_body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", @api_version},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, response} -> parse_response(response)
      {:error, reason} -> {:error, {:network_error, reason}}
    end
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
