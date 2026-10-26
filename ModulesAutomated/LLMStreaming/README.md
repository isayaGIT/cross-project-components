# LLMStreaming

A reusable, Foundation-based streaming transport for the OpenAI-compatible chat-completions endpoint. It ports the connection lifecycle in `cloud/llm/stream.py` and emits normalized events incrementally rather than buffering the entire response. It deliberately complements, rather than replaces, `LLMTransport`, `LLMGateway`, `LLMRouting`, and `AnthropicMessages`.

## Source mapping

- `open_completion(cfg, payload, label, timeout, retries)` → `LLMStreamingClient.openCompletion(configuration:payload:label:options:)`
- `transport.normalize_chat_url` and `transport.is_v4_model` → shared `LLMTransport` helpers.
- `transport.STREAM_HEADERS_BASE` → `LLMTransport.streamHeadersBase`.
- Source HTTP connection / response ownership → `LLMCompletionStream` and its cancellable `AsyncThrowingStream`.
- SSE byte framing and event decoding → private `LLMServerSentEventsParser` plus typed `LLMStreamEvent`.

## Public API

- `LLMStreamingClient`: injectable `URLSession` and the existing `LLMAPIKeyValidating` policy.
- `LLMStreamOptions`: timeout, retries, and linear retry delay.
- `LLMCompletionStream`: normalized endpoint, effective model, HTTP status, incremental event sequence, and explicit cancellation.
- `LLMStreamEvent`: content/reasoning/refusal deltas, indexed tool-call fragments, usage, completion, raw data, or named provider-specific SSE events.
- `LLMStreamUsage`: prompt/completion token counts and optional prompt-cache hit/miss counts.
- `LLMStreamingError`: typed configuration, HTTP, SSE, upstream and exhausted-retry errors.

## Usage

```swift
let client = LLMStreamingClient()
let stream = try await client.openCompletion(
    configuration: LLMTransportConfiguration(
        apiURL: "https://api.example.com/v1",
        model: "deepseek-v4-flash",
        apiKey: apiKey
    ),
    payload: [
        "messages": [["role": "user", "content": "Hello"]],
        "temperature": 0.8,
        "max_tokens": 1024
    ],
    label: "chat:default",
    options: LLMStreamOptions(timeout: 60, retries: 2)
)

for try await event in stream.events {
    switch event {
    case .contentDelta(let text):
        consume(text)
    case .reasoningDelta:
        // Keep reasoning separate from user-visible answer text.
        break
    case .toolCallDelta(let choiceIndex, let index, let id, let type, let name, let arguments):
        // Accumulate fragments by (choiceIndex, index); arguments are not complete JSON per event.
        accumulateToolCall(choiceIndex, index, id, type, name, arguments)
    case .refusalDelta(let text):
        handleRefusal(text)
    case .usage(let usage):
        record(usage)
    case .completed:
        break
    case .raw(let data):
        logProviderEvent(data)
    case .providerEvent(let name, let data):
        logNamedProviderEvent(name, data)
    }
}
```

The `consume`, `record`, and `logProviderEvent` calls above are application-provided functions.

## Behavior and integration

- The API URL follows the existing `LLMTransport.normalizeChatURL` rules; only HTTP(S) URLs with a host and without embedded userinfo are accepted.
- Uses bearer authorization and the existing stream headers. It does not set `Accept-Encoding`, avoiding unexpected compressed SSE bodies.
- The model is taken from payload when non-empty, otherwise from configuration. DeepSeek V4-family models receive `thinking: { type: disabled }` only when the payload has not already specified `thinking`.
- Forces `stream: true` and defaults `stream_options.include_usage` to true, while preserving caller-provided values for the latter. This matches the chat proxy's streaming behavior; other payload fields are preserved.
- Connection failures and HTTP 5xx responses retry up to the configured count with the source's 0.6-second linear backoff. HTTP 4xx responses are returned as typed errors with a bounded response-body excerpt. Streaming errors after a successful response are surfaced to the consumer and are not automatically retried, because replaying a partially delivered completion can duplicate output.
- SSE framing supports multi-line `data:` fields, named `event:` fields, and comment heartbeats. Parsing is performed after complete lines arrive, so UTF-8 characters split across network chunks are not decoded prematurely. OpenAI-compatible content, reasoning, refusal, indexed tool-call fragments, finish reason, usage, `[DONE]`, and upstream error objects are surfaced explicitly. Unknown named SSE events retain their event name and payload.
- The stream is consumed incrementally using `URLSession.AsyncBytes`; cancellation propagates to the reader task. The configured URLRequest timeout bounds request inactivity according to URLSession behavior; no separate wall-clock deadline or independent idle watchdog is added.
- The original Python `stream.py` returns the raw HTTP connection to `server.py`, which forwards raw SSE bytes and owns connection cleanup. This Swift module exposes parsed events instead of raw byte-for-byte forwarding. For a byte-preserving proxy, add a separate raw-byte API rather than re-encoding parsed events.
- The source call graph routes Anthropic requests through `cloud/llm/anthropic.py`, where `AnthropicMessages.StreamConverter` handles Anthropic SSE-to-OpenAI conversion. This module intentionally does not duplicate that converter. For Anthropic upstream streaming, use the existing converter with a true streaming HTTP byte source; the current `AnthropicMessages.openMessages` implementation uses buffered `URLSession.data(for:)` and is not itself end-to-end streaming.
- The existing gateway's in-flight idempotency mechanism is for non-streaming calls and is not applied to live streams. Route resolution remains the caller's responsibility; pass the resolved `LLMTransportConfiguration` from the existing routing/gateway integration.

## Open-source research and license decision

- [mattt/EventSource](https://github.com/mattt/EventSource) is an MIT-licensed Swift SSE client with an AsyncSequence API, multi-line data, standard fields and multiple newline formats. It is more full-featured and actively maintained, but its connection-management abstraction is designed around EventSource-style GET/reconnection rather than this project's authenticated POST completion contract. The module implements only the SSE framing subset required by the source instead of introducing an additional dependency. Reference: [repository](https://github.com/mattt/EventSource).
- [DePasqualeOrg/swift-sse](https://github.com/DePasqualeOrg/swift-sse) is a dependency-free, MIT-licensed low-level parser aligned with WHATWG SSE framing. It is a relevant alternative for event parsing, but the needed framing surface is small and the subsystem already depends on Foundation/URLSession, so no external parser dependency was added. Reference: [repository](https://github.com/DePasqualeOrg/swift-sse).
- [swift-server/async-http-client](https://github.com/swift-server/async-http-client) is a maintained Apache-2.0 HTTP client with async body streaming and backpressure. It is attractive for server-side Swift deployments, but adds SwiftNIO and package integration costs for this Apple-platform-oriented module; `URLSession.AsyncBytes` is the smaller fit here. Reference: [repository](https://github.com/swift-server/async-http-client).
- No upstream source code was copied. The implementation is an original adaptation of the project's supplied backend contract and documented protocol behavior. No new third-party dependency or license obligation is introduced.

## Limitations

- Requires a platform/toolchain that provides `URLSession.AsyncBytes` and `URLSession.bytes(for:)` (Apple platforms from the modern async URLSession generation; verify the deployment target before integration).
- Request-body JSON remains `[String: Any]` to match adjacent transport/gateway APIs; callers must pass JSON-serializable values.
- This API yields normalized events rather than the original raw bytes. Tool-call arguments are incremental fragments and must be assembled by `(choiceIndex, index)` before parsing the complete JSON. Automatic stream reconnect, proxy telemetry, and provider-specific Anthropic network transport remain out of scope.
- The module has not been built or tested, as required for this migration cycle. Integration should confirm deployment-target availability and strict-concurrency diagnostics in the consuming target.
