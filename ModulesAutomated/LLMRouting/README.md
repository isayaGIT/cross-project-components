# LLMRouting

A reusable Swift subsystem derived from `cloud/llm/routing.py`, `cost.py`, `telemetry.py`, `__init__.py`, and `providers.py`. It consolidates task routing, model cost estimation, usage persistence, and compatibility bindings while leaving provider request execution to the existing `LLMGateway`, `LLMTransport`, and `AnthropicMessages` components.

## Files

- `LLMRouting.swift` — profile/configuration models, task route resolution, specialized chat/moments/TTS slots, safe key diagnostics, JSON metadata preservation.
- `CostAccounting.swift` — ordered substring-based USD pricing and token cost estimation.
- `UsageTelemetry.swift` — actor-isolated usage aggregation, logging, and atomic JSON persistence.
- `LLMRoutingFacade.swift` — unified entry point and injected compatibility closures for gateway/provider aliases.

## Routing behavior

`LLMRouting.Dependencies` injects the route file URL, provider configuration URL, profile directory, profile-key policy, moments configuration loader, and TTS annotation configuration loader. Missing or malformed route/provider JSON behaves as empty configuration, matching the Python implementation. The chat slot prefers `profileId`, then `provider`, and defaults to `deepseek`; if the selected profile cannot be found, it attempts the `deepseek` profile. Model overrides are retained when a fallback profile is used.

Tasks whose `has_ui_slot` value is Python-falsey resolve through the configured provider ID or name and use the route's model override. This includes a missing field, null, false, numeric zero, an empty string, and empty JSON containers; previously the Swift port treated a missing field as a UI-slot task. An empty task object itself remains falsey, matching Python's outer `if task` guard. A missing provider, `ui` provider, or unresolved provider falls back to chat. Route values are decoded independently as JSON values so a non-string field in one task does not invalidate the entire route document; unsupported provider/model types safely become empty strings and therefore use the existing fallback. `moments`, `comments`, `vision`, `selector`, and `private` use their corresponding profile/model fields and fall back to chat while retaining an explicit slot model. `ttsExtract` reads only the source-compatible nested `extract` section (or top-level legacy `profileId`/`model` settings), and `ttsAnnotate` reads `annotate` (or the same top-level legacy settings). The Swift resolver intentionally does not prefer extra `ttsExtract`/`ttsAnnotate` nested keys that the Python source never reads.

## Cost and telemetry

`LLMCostAccounting` applies the first case-insensitive model substring match in the declared order, uses a default rate of USD 0.27 per million tokens, coerces invalid token values to zero, and applies one model-level rate to prompt plus completion tokens. String token values accept surrounding whitespace and valid Python-style digit separators (for example, `"1_000"`), matching `int(value)` behavior more closely than Swift's strict `Int(String)` initializer.

`LLMUsageTelemetry` records task and daily aggregates for call counts, success/failure counts, prompt/completion/total tokens, latency, cost, and cache-hit/cache-miss tokens. It preserves unknown top-level fields from an existing usage document, repairs absent `tasks` and `daily` dictionaries, writes atomically, and logs only the API hostname rather than the full URL or credential. The injected clock and logging closure let the host retain its timezone and logging conventions. The default log clock explicitly uses `Asia/Shanghai`; inject the host's authoritative Beijing-time formatter when exact formatting parity with the Python implementation is required. Each `record` and `getUsage` reloads the persisted document first, matching Python's read-on-operation behavior and avoiding routine lost updates from stale actor-local snapshots when another instance or process has written usage data. This is not a cross-process transaction or file lock, so simultaneous writers can still race.

## Gateway and transport integration

The subsystem deliberately does not reimplement HTTP calls. Supply `LLMProviderCompatibility` closures that delegate to the existing gateway and transport implementations. The host adapter should convert `LLMRouting.ResolvedConfiguration` to the gateway's `LLMGatewayConfiguration`, convert the messages/result types required by the existing gateway entry points, and delegate URL normalization, response-content extraction, V4 model detection, and browser user-agent constants to `LLMTransport`. The closure boundary avoids assuming that independently generated component folders are already compiled into a single Swift module.

The existing `LLMGateway` defines an async routing protocol and uses `LLMGatewayConfiguration`; if the host compiles these components into the same target, a small adapter can conform to `LLMGatewayRouting` and forward `resolve(taskKey:)` to `LLMRouting.resolve(_:)`. That adapter belongs at the integration boundary rather than duplicating routing logic here.

## Security and limitations

The router does not read hard-coded application paths, retrieve secrets from an implicit store, or contact upstream endpoints. The host must supply the real profile-key resolver. `keyProblem` only detects an absent key or a visibly masked value containing `****`; it does not validate credentials with a provider. Telemetry never stores API keys or authorization headers. The facade's gateway methods intentionally fail with a typed error when compatibility closures were not supplied.

## Example

```swift
let router = LLMRouting(dependencies: .init(
    llmRoutesURL: configDirectory.appendingPathComponent("llm_routes.json"),
    providerConfigURL: configDirectory.appendingPathComponent("_provider_config.json"),
    loadProfiles: { profiles },
    profileKey: { profile in keyStore.key(for: profile) },
    loadMomentsConfig: { momentsConfig },
    loadTTSAnnotationConfig: { ttsConfig }
))

let selected = router.resolve("comments")
let cost = LLMCostAccounting.estimateCost(
    model: selected.model,
    promptTokens: 1_000,
    completionTokens: 500
)

let telemetry = LLMUsageTelemetry(configuration: .init(usageURL: usageFileURL))
await telemetry.record(.init(
    taskKey: "comments",
    model: selected.model,
    apiURL: selected.apiUrl,
    promptTokens: 1_000,
    completionTokens: 500,
    latencyMilliseconds: 840,
    succeeded: true
))
```

## Compatibility audit and upstream research

This audit compared the supplied Python routing and telemetry contracts directly with the Swift implementation. Routing handles Python-falsey/missing `has_ui_slot` values, exact `extract`/`annotate` TTS keys, and per-task malformed provider/model values without invalidating the whole route document. Telemetry now refreshes its JSON snapshot before recording and reading, and its default log clock uses Beijing time. Malformed route provider/model values safely fall back rather than reproducing Python's `AttributeError` for calling `.strip()` on a non-string; this is an intentional resilience difference. Usage persistence remains atomic per write but does not provide cross-process locking or transaction isolation.

Research consulted Apple's official Foundation documentation for [custom Codable decoding](https://developer.apple.com/documentation/foundation/encoding-and-decoding-custom-types) and [atomic data writes](https://developer.apple.com/documentation/foundation/nsdata). These APIs match the existing Foundation-only architecture and explain the custom decoding and atomic persistence choices. No third-party implementation or dependency was adopted, so no external source code or additional license obligations were introduced. The existing atomic write is appropriate for the app's private usage-data location; do not use this pattern for attacker-writable public directories without applying the file-operation security guidance in Apple's documentation.

No tests, builds, or Git operations were run, as required by the migration workflow.
