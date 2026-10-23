# BehaviorRoutingService

A reusable backend-only Swift port of `cloud/services/behavior_route.py`. It classifies a message into `enter_nsfw`, `stay`, `exit_nsfw`, or `unclear`. It does not generate replies, persist channel state, or implement frontend sticky-exit policy.

## Source mapping

- `BehaviorRouteModels.swift`: route/cue/mode enums and public result contracts.
- `BehaviorRouteJSON.swift`: JSON decoding, Python-style truthiness, string coercion, and confidence conversion.
- `BehaviorRoutingService.swift`: heuristic rules, prompt construction, parser orchestration, and asynchronous LLM pipeline.
- Selected Python source: `cloud/services/behavior_route.py` only. Browser-side code and application-wide server integration are outside this module boundary.

## Public API

Instantiate `BehaviorRoutingService()` and call `run(llmJSONCall:userMessage:recentDialog:currentMode:)`. The injected asynchronous closure receives the full system-plus-user prompt and returns the model's raw text. The result contains `intent`, `confidence`, `cue`, and `meta`.

For finer-grained use, call `heuristicIntent(userMessage:currentMode:)`, `buildUserPrompt(userMessage:recentDialog:currentMode:)`, or `parseRouteJSON(_:)`. `BehaviorRouteResult.jsonObject()` produces the source-compatible dictionary shape.

## Example

```swift
let router = BehaviorRoutingService()
let result = await router.run(
    llmJSONCall: { prompt in
        // Integrate with the host application's existing LLM gateway.
        try await llmGateway.completeJSON(prompt: prompt)
    },
    userMessage: "换个话题吧",
    recentDialog: "",
    currentMode: "nsfw"
)
print(result.intent.rawValue)
print(result.jsonObject())
```

`llmGateway.completeJSON(prompt:)` is illustrative host code, not an API provided by this module. The host owns provider selection, networking, credentials, retries, and logging.

## Behavior

- Hard-exit patterns are evaluated before hard-enter patterns.
- Empty input immediately returns `unclear`, confidence `1.0`, cue `other`, and avoids the LLM call.
- In NSFW mode, recognized short acknowledgements return `stay` with confidence `0.8`; the source aftercare pattern selects `aftercare` versus `other`.
- In daily mode, a message with at most two Unicode scalars and none of the source exclusion characters returns `unclear`, confidence `0.7`, cue `daily`.
- The full pipeline maps any mode other than the exact string `nsfw` to `daily`; the standalone heuristic method uses exact `nsfw` and `daily` comparisons.
- Prompt content and ordering preserve the Chinese source instructions. Recent dialogue is truncated to the final 1,800 Unicode scalars.
- JSON parsing removes lowercase `json` fences and generic fences, tries the whole response, then tries an embedded object.
- Invalid intents normalize to `unclear`, invalid cues to `other`, and confidence is converted and clamped to 0...1. Falsey intent/cue values use the source defaults.
- LLM exceptions return `unclear`, confidence `0`, cue `other`, and metadata containing `currentMode` and an error description limited to 200 characters. The error result omits `fastPath`.

## Dependencies and limitations

Requires Foundation and CoreFoundation only. No third-party Swift packages are required. The host supplies LLM execution. Sticky-exit policy is explicitly outside the Python backend module and is not ported here.

The Swift implementation matches the documented source contracts and common Python conversion semantics. Python and Swift still differ for certain exotic dictionary representations, Unicode whitespace cases, and malformed JSON edge cases; exact parity for every Python runtime behavior is not guaranteed. No tests, builds, or Git operations were run.