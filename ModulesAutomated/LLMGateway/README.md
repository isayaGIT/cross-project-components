# LLMGateway

A reusable Swift gateway for centralized, non-streaming language-model calls. It ports the behavior in `cloud/llm/gateway.py` while keeping routing and HTTP transport injectable, so the module does not invent routing configuration, provider APIs, or credentials.

## Source mapping

- `resolve(task_key)` delegates to the injected `LLMGatewayRouting` implementation.
- `call(...)` validates the label, resolves configuration when needed, normalizes messages, prepends the JSON-only system prompt when requested, and delegates every non-streaming request to `LLMGatewayTransport`.
- `chat(task_key, ...)` uses the task key as both route and accounting label.
- `callWithConfiguration(...)` preserves the legacy explicit-configuration calling pattern.
- `makeIdempotencyKey(...)` hashes the label, model, API URL, and messages with SHA-256. The API key is excluded, matching the Python source.
- In-flight requests with the same non-empty idempotency key share one asynchronous task and its result or error.

## Public API

- `LLMGateway`
- `LLMGatewayConfiguration`
- `LLMGatewayMessage`
- `LLMGatewayJSONValue`
- `LLMGatewayRouting`
- `LLMGatewayTransport`
- `LLMGatewayError`

The module uses Foundation and CryptoKit. The project must provide conforming routing and transport adapters. An adapter for the existing `LLMTransport` module should forward to its centralized `postChat` implementation and preserve its response type.

## Usage

```swift
let gateway = LLMGateway(routing: routingAdapter, transport: transportAdapter)

let response = try await gateway.chat(
    taskKey: "memory_extract",
    messages: [
        LLMGatewayMessage(role: "user", content: "Extract the key facts.")
    ],
    jsonMode: true,
    idempotencyKey: "memory-extract-request-123"
)
```

For callers with an already-resolved configuration:

```swift
let response = try await gateway.callWithConfiguration(
    configuration,
    label: "comments",
    messages: [LLMGatewayMessage(role: "user", content: "Summarize this comment.")]
)
```

## Behavior and limitations

- The gateway does not implement streaming; the source delegates streaming to a separate module.
- Routing-table loading, telemetry, usage accounting, and provider-specific HTTP behavior remain the responsibility of the existing routing and transport adapters.
- The source Python implementation accepts arbitrary Python objects and uses `default=str` during fingerprint serialization. Swift supports JSON-compatible values and falls back to `String(describing:)` for unsupported values during fingerprint canonicalization; exact cross-language fingerprints are therefore guaranteed only for equivalent JSON-compatible inputs whose number and string serialization matches.
- In-flight deduplication is scoped to one `LLMGateway` instance and only while the operation is active. Results are not cached after completion. Unlike the Python implementation's explicit waiter timeout, awaiting a shared Swift task does not currently impose an independent per-waiter timeout.
- The source Python implementation uses a process-global table, while this implementation uses actor-isolated instance state. Applications requiring deduplication across multiple gateway instances should share a single gateway instance.
- No credentials, filesystem paths, provider-specific endpoint assumptions, or app-specific UI are embedded in this module.
