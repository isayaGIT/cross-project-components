# LLMTransport

A reusable Swift implementation of the non-streaming HTTP transport in `cloud/llm/transport.py`. It centralizes OpenAI-compatible `/chat/completions` requests so application code does not need to duplicate provider-specific HTTP handling.

## Source mapping

- `is_v4_model` → `LLMTransport.isV4Model(_:)`
- `normalize_chat_url` → `LLMTransport.normalizeChatURL(_:)`
- `extract_content` → `LLMTransport.extractContent(from:)`
- `post_chat` → `LLMHTTPTransport.postChat(configuration:label:messages:temperature:maxTokens:timeout:retries:extraBody:)`
- `BROWSER_UA` and `STREAM_HEADERS_BASE` → `browserUserAgent` and `streamHeadersBase`

## Public API

`LLMTransportConfiguration` carries the API URL, model identifier and API key. `LLMChatMessage` represents a role/content message. `LLMHTTPTransport` performs asynchronous requests through an injectable `URLSession`, validates configuration and keys, handles retryable network failures and server errors, and optionally records usage through `LLMTransportTelemetry`. `LLMChatResult` exposes trimmed assistant content, normalized prompt/completion token counts, and the original decoded JSON object. Errors are represented by `LLMTransportError`.

The key validator is injected through `LLMAPIKeyValidating`. The default validator only rejects an empty key; applications should provide their routing layer's stricter validation policy where needed. Telemetry is also injected because the source's Python `routing` and `telemetry` modules are outside this assigned file.

## Usage

```swift
let transport = LLMHTTPTransport()
let configuration = LLMTransportConfiguration(
    apiURL: "https://api.example.com/v1",
    model: "deepseek-v4-flash",
    apiKey: apiKey
)

let result = try await transport.postChat(
    configuration: configuration,
    label: "assistant",
    messages: [LLMChatMessage(role: "user", content: "Hello")]
)
print(result.content)
print(result.usage.promptTokens, result.usage.completionTokens)
```

## Behavior and limitations

- URLs are normalized to a `/chat/completions` endpoint using the source rules. An empty or whitespace-only URL remains invalid.
- DeepSeek V4-related model names receive `thinking: { type: disabled }` unless `extraBody` overrides it.
- Requests use bearer authentication, JSON content type, the source-compatible browser user agent, configurable timeouts, and a configurable number of retries.
- Retryable URL loading failures and HTTP 5xx responses are retried. Client errors, invalid JSON, malformed response structures, and empty assistant content fail immediately. This deliberately distinguishes server/network failures from application-level response errors.
- Missing usage values are normalized to zero in the public result. Cache hit/miss values are passed to telemetry when available.
- `extraBody` overrides generated request fields, matching Python dictionary update semantics. Callers should avoid overriding fields unless intentional.
- The source accepts arbitrary message objects and converts non-list input to a single user message. This Swift API uses typed string-content messages; multimodal message payloads and the Python fallback for arbitrary input are not implemented.
- Python telemetry and routing-key policy are represented by injectable protocols, not fabricated. Exact compatibility requires adapting those protocols to the existing application modules.
- Streaming request execution, SSE parsing, and streaming connection lifecycle are intentionally not included; those behaviors belong to `cloud/llm/stream.py` and the separate streaming implementation.
- `raw` is `[String: Any]` to preserve provider-specific JSON fields, so it is not `Codable` or `Sendable`. The transport itself is `Sendable`; consumers should keep raw response objects within an appropriate isolation boundary when using strict Swift concurrency.
