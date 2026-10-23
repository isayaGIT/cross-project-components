# AutomaticVoiceDecisionService

A reusable native Swift port of `cloud/services/should_send_voice.py`. The subsystem decides whether a newly generated assistant reply is better delivered as a voice-only bubble. It is deliberately conservative: a fast rejection or any model/parsing error results in `sendVoice == false`.

## Files

- `VoiceDecisionModels.swift` — public result, metadata, policy configuration, and parsing error models.
- `AutomaticVoiceDecisionService.swift` — fast-path rules, prompt construction, response parsing, confidence gating, and async orchestration.

## Integration

The service does not own an HTTP client or a model SDK. Inject the existing application's LLM JSON gateway as an async closure:

```swift
let voiceService = AutomaticVoiceDecisionService()
let decision = await voiceService.runAutoVoiceDecide(
    assistantText: "想你了",
    recentDialog: "对方：你在做什么？",
    partsCount: 1,
    llmJSONCall: { prompt in
        // Forward `prompt` to the existing JSON-mode LLM gateway.
        // Return the model's textual response.
        try await existingLLMGateway.callJSON(prompt: prompt)
    }
)

if decision.sendVoice {
    // Deliver the assistant reply using the voice-only presentation path.
}
```

The closure above is illustrative; adapt its invocation to the application's existing gateway API. No transport dependency is introduced by this module.

## Behavior

1. Trim the candidate text. Reject empty text, multi-part output, embedded newlines, URLs, fenced code, text consisting only of parenthesized stage directions, or content exceeding the configured Unicode-scalar limit.
2. If the fast path does not reject, compose the original Chinese system prompt and a user prompt. The recent dialog is truncated to its final 1200 Unicode scalars by default.
3. Parse the model's JSON response, accepting a JSON object directly or a greedily extracted object after a JSON decoding failure. Fence removal intentionally follows the source's case-sensitive regular expressions.
4. Interpret `sendVoice` from common true strings (`1`, `true`, `yes`, `y`) or JSON truthiness. Clamp confidence and reject a voice decision below 0.55.
5. Attach `meta.fastPath = true` to fast rejections and `meta.fastPath = false` to model-path results. Model invocation or parsing exceptions return `sendVoice = false`, `confidence = 0`, `reason = "llm-error"`, and bounded error metadata.

## API

- `hardReject(_:partsCount:)` — returns a fast-path result or `nil` when model evaluation is required.
- `buildUserPrompt(assistantText:recentDialog:)` — builds the user prompt without the system prompt.
- `parseDecisionJSON(_:)` — parses the model response. Malformed JSON returns `parse-fail`; a valid JSON scalar or array throws `expectedJSONObject`, which the orchestration method converts to `llm-error`.
- `runAutoVoiceDecide(assistantText:recentDialog:partsCount:llmJSONCall:)` — executes the complete asynchronous decision path.

`VoiceDecisionConfiguration` exposes the source policy limits for controlled reuse. Defaults preserve the source behavior: 40 characters, 1200 recent-dialog characters, 80 reason characters, 200 error characters, and a 0.55 minimum voice confidence.

## Compatibility notes

The implementation uses Unicode-scalar counts to match Python's code-point-oriented `len` and slicing behavior more closely than Swift's grapheme-cluster `String.count`. It preserves the source's greedy embedded-object extraction and fail-closed orchestration. Python's `str(...)` representation of unusual nested JSON values is approximated; normal string-valued `reason` fields retain their exact behavior. The source's exception text is represented using Swift's `localizedDescription`, since Swift errors do not expose Python exception strings.

This artifact has not been built or tested, in accordance with the task constraint not to run builds or tests.