# AnthropicMessages

A dependency-free Swift module porting the behavior of `cloud/llm/anthropic.py` into reusable Foundation APIs for iOS and macOS.

## Source mapping

- `is_claude_model` → `AnthropicMessages.isClaudeModel(_:)`
- `normalize_messages_url` → `normalizeMessagesURL(_:)`
- `split_system_for_cache` → `splitSystemForCache(_:)`
- `build_messages_request` → `buildMessagesRequest(model:messages:temperature:maxTokens:stream:)`
- `_anthropic_headers` → `headers(apiKey:)`
- `open_messages` → `openMessages(configuration:body:label:options:session:)`
- `anthropic_usage_to_openai` → `anthropicUsageToOpenAI(_:)`
- `convert_json_response_to_openai` → `convertJSONResponseToOpenAI(_:)`
- `_openai_chunk` and `pipe_stream_as_openai` → `StreamConverter` and `convertStreamToOpenAI(_:)`

## Public API

`Configuration` accepts `apiURL`, `apiKey`, and `model`, or can be initialized from a dictionary using the original backend keys `apiUrl`, `apiKey`, and `model`. `RequestOptions` configures temperature, token limit, streaming mode, timeout, and retry count. `HTTPResult` contains the response bytes, status code, normalized URL, model, start time, and last retry error. `Usage` provides typed token counts and a dictionary matching the OpenAI-compatible usage field names.

`buildMessagesRequest` merges consecutive leading system messages, separates stable and volatile prompt text using the original markers, adds ephemeral cache control to the stable section, filters unsupported roles, and inserts the original fallback user message when necessary. Request headers preserve both `x-api-key` and bearer authorization, matching the source behavior.

`openMessages` performs a POST with `URLSession`, retries transport failures and HTTP 5xx responses, and returns non-5xx responses to the caller for upstream error handling. Retry delays follow the source's 0.6-second linear backoff. The request body uses Foundation JSON serialization.

`StreamConverter` is incremental: pass each received SSE byte chunk to `append(_:isFinal:)`, write its returned output bytes immediately, and pass `isFinal: true` when the upstream stream ends. The final call emits the OpenAI finish chunk and `[DONE]` marker and returns accumulated usage. This permits integration with a streaming transport without binding the module to a particular HTTP streaming implementation.

## Usage example

```swift
import Foundation

let config = AnthropicMessages.Configuration(
    apiURL: "https://api.example.com/v1/chat/completions",
    apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "",
    model: "claude-sonnet"
)

let messages: [[String: Any]] = [
    ["role": "system", "content": "You are a helpful assistant."],
    ["role": "user", "content": "Explain prompt caching." ]
]

let body = AnthropicMessages.buildMessagesRequest(
    model: config.model,
    messages: messages,
    stream: false
)

let result = try await AnthropicMessages.openMessages(
    configuration: config,
    body: body,
    label: "example"
)

if (200..<300).contains(result.statusCode) {
    let openAIResponse = try AnthropicMessages.convertJSONResponseToOpenAI(result.data)
    print(String(decoding: openAIResponse, as: UTF8.self))
}
```

## Limitations

- `openMessages` uses `URLSession.data(for:)`, so its HTTP response is buffered in memory. For true end-to-end streaming, connect a streaming URLSession transport to `StreamConverter` and forward chunks as they arrive. The SSE conversion itself supports incremental input and preserves incomplete lines between calls.
- The original Python module inherits `STREAM_HEADERS_BASE` from `transport.py`. This module reproduces the relevant JSON, SSE, and authentication headers, but cannot inherit additional deployment-specific headers without that adjacent module's configuration.
- The original `http.client` connection object and Python file-like writer are intentionally replaced with Swift value types and byte buffers. No routing, telemetry, cost accounting, or application-specific credential storage is included because those belong to adjacent backend modules.
- The source's stream conversion emits a role chunk on `message_start`, text chunks on `content_block_delta`, and usage/finish chunks when the stream ends. It does not convert tool calls, images, or other non-text content blocks; this implementation preserves that behavior.
