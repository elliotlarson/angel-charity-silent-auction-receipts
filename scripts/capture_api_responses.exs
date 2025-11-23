# Script to capture real Anthropic API responses for test fixtures
# Run with: mix run scripts/capture_api_responses.exs

# Load .env
if File.exists?(".env") do
  {:ok, vars} = Dotenvy.source(".env")
  Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)
end

api_key = System.get_env("ANTHROPIC_API_KEY")

if is_nil(api_key) or api_key == "" do
  IO.puts("Error: ANTHROPIC_API_KEY not set")
  System.halt(1)
end

# Success case
IO.puts("Capturing successful response...")

success_response =
  Req.post!(
    "https://api.anthropic.com/v1/messages",
    json: %{
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 1024,
      messages: [
        %{
          role: "user",
          content: "Say hello"
        }
      ]
    },
    headers: [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]
  )

success_fixture = %{
  status: success_response.status,
  body: success_response.body
}

File.write!(
  "test/fixtures/anthropic_success.json",
  Jason.encode!(success_fixture, pretty: true)
)

IO.puts("✓ Saved test/fixtures/anthropic_success.json")

# 401 error case
IO.puts("Capturing 401 error response...")

error_response =
  Req.post!(
    "https://api.anthropic.com/v1/messages",
    json: %{
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 1024,
      messages: [
        %{
          role: "user",
          content: "Test prompt"
        }
      ]
    },
    headers: [
      {"x-api-key", "invalid-key-12345"},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]
  )

error_fixture = %{
  status: error_response.status,
  body: error_response.body
}

File.write!(
  "test/fixtures/anthropic_401_error.json",
  Jason.encode!(error_fixture, pretty: true)
)

IO.puts("✓ Saved test/fixtures/anthropic_401_error.json")
IO.puts("\nAPI responses captured successfully!")
