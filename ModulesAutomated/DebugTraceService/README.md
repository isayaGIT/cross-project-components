# DebugTraceService

A reusable Swift port of `cloud/services/debug_traces.py` built on Foundation. It provides JSON-backed recent and pinned trace collections, trace sanitization, mutation operations, usage estimation, and usage backfilling.

## Integration

Add `DebugTraceModels.swift` and `DebugTraceService.swift` to the target that owns backend or application persistence code. No third-party package is required. The service is an actor, so call its asynchronous methods with `await` from outside the actor.

```swift
let traceURL = applicationSupportDirectory.appendingPathComponent("debug-traces.json")
let traces = DebugTraceService(fileURL: traceURL)

let saved = try await traces.append([
    "model": .string("example-model"),
    "userInput": .string("Hello"),
    "systemPrompt": .string("You are an assistant."),
    "rawOutput": .string("Hi there!")
])

let collection = await traces.listAll()
let recent = collection.recent
let pinned = collection.pinned
```

## API

- `listAll()` returns recent and pinned JSON-compatible records plus `recentMax`.
- `append(_:)` inserts a new trace or updates an existing record by ID. Updates preserve `rawOutput` and `recalls` when omitted.
- `pin(id:raw:)` promotes an existing recent trace or pins a supplied trace. Pass `raw: nil` to pin a stored record by ID.
- `delete(id:)` removes an ID from both collections and reports whether anything was removed.
- `patch(id:fields:)` updates supported fields: `rawOutput`, `userInput`, `systemPrompt`, `recalls`, `usage`, and `usageSource`.
- `estimateUsageCalibrated(model:systemPrompt:rawOutput:)` returns a token estimate and its `calibrated` source label.
- `backfillUsage(model:counter:onlyMissing:)` updates recent and pinned records and returns the number updated. The optional counter receives the system prompt and raw output and returns a dictionary of normalized token fields.

## Persistence and compatibility notes

The persisted JSON root contains `recent` and `pinned` arrays. Recent records are newest-first and limited to five; pinned records have no limit. A missing or malformed file is treated as an empty collection. Writes use Foundation's atomic file-write option and create the parent directory if necessary.

Timestamps with an ISO-8601 timezone are converted to Beijing time (`UTC+08:00`) and formatted as `yyyy-MM-dd'T'HH:mm:ss`. Naive timestamp strings are normalized to `T` separation and truncated to 19 characters. Missing or blank timestamps use the injected clock.

The sanitizer retains the source module's main field whitelist and recall limits. Token estimation uses Unicode scalar counts to approximate Python's code-point `len` behavior. Claude/Anthropic models use a 0.85 characters-per-token divisor; other models use 1.6. Models matching thinking/reasoning markers use `Int(outputCharacterCount * 2.46)` for completion estimates.

Actor isolation serializes calls through one `DebugTraceService` instance. It does not coordinate concurrent writes from separate instances or other processes targeting the same file URL; applications should share one instance per store. This port is a backend persistence component and intentionally contains no UI, networking, tests, or build configuration.
