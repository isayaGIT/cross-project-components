# LLMRouting

A reusable Swift subsystem derived from `cloud/llm/routing.py`, `cost.py`, `telemetry.py`, `__init__.py`, and `providers.py`. It consolidates task routing, model cost estimation, usage persistence, and compatibility bindings while leaving provider request execution to the existing `LLMGateway`, `LLMTransport`, and `AnthropicMessages` components.

## Files

- `LLMRouting.swift` — profile/configuration models, task route resolution, specialized chat/moments/TTS slots, safe key diagnostics, JSON metadata preservation.
- `CostAccounting.swift` — ordered substring-based USD pricing and token cost estimation.
- `UsageTelemetry.swift` — actor-isolated usage aggregation, logging, and atomic JSON persistence.
- `LLMRoutingFacade.swift` — unified entry point and injected compatibility closures for gateway/provider aliases.

## Routing behavior

`LLMRouting.Dependencies` injects the route file URL, provider configuration URL, profile directory, profile-key policy, moments configuration loader, and TTS annotation configuration loader. Missing or malformed route/provider JSON behaves as empty configuration, matching the Python implementation. The chat slot prefers `profileId`, then `provider`, and defaults to `deepseek`; if the selected profile cannot be found, it attempts the `deepseek` profile. Model overrides are retained when a fallback profile is used.

Tasks with `has_ui_slot == false` resolve through the configured provider ID or name and use the route's model override. A missing provider, `ui` provider, or unresolved provider falls back to chat. `moments`, `comments`, `vision`, `selector`, and `private` use their corresponding profile/model fields and fall back to chat while retaining an explicit slot model. `ttsExtract` and `ttsAnnotate` accept their named nested sections, legacy `extract`/`annotate` sections, or top-level `profileId`/`model` settings.

## Cost and telemetry

`LLMCostAccounting` applies the first case-insensitive model substring match in the declared order, uses a default rate of USD 0.27 per million tokens, coerces invalid token values to zero, and applies one model-level rate to prompt plus completion tokens.

`LLMUsageTelemetry` records task and daily aggregates for call counts, success/failure counts, prompt/completion/total tokens, latency, cost, and cache-hit/cache-miss tokens. It preserves unknown top-level fields from an existing usage document, repairs absent `tasks` and `daily` dictionaries, writes atomically, and logs only the API hostname rather than the full URL or credential. The injected clock and logging closure let the host retain its timezone and logging conventions. The default display-time closure uses the host locale; inject a Beijing-time formatter when exact parity with the Python implementation is required.

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

No tests, builds, or git operations are part of this artifact-generation step.
