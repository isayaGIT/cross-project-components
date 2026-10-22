# MessageComposer (iOS)

A reusable SwiftUI extraction based on ZPing's `InputSection` UI. It includes the warm input capsule, attachment/voice/send/call controls, voice-first and text-first layouts, recording waveform, transcribing/cancel states, optional action-bracket press, error banner, and bar-height callback.

The app owns microphone permissions, the recorder and speech recognizer, transcription, attachment sheet, and message/call behavior. Reflect engine changes through `voiceState`, `audioLevels`, and `voiceError`; handle button intents through callbacks. The component has no dependency on ZPing's `InputBarLogic`, `Theme`, or app models.

```swift
import CrossProjectComponentsIOS

@State private var message = ""
@State private var mode = MessageComposer.InputMode.text
@State private var voiceState = MessageComposer.VoiceState.idle

MessageComposer(
    text: $message,
    mode: $mode,
    voiceState: $voiceState,
    onSend: { messageToSend in sendMessage(messageToSend) },
    onStartVoice: { startRecorder() },
    onStopVoice: { stopAndTranscribe() },
    onCancelVoice: { cancelRecorder() },
    onDirectSend: { stopAndTranscribeThenSend() },
    onAddAttachment: { showAttachments = true },
    onCall: { startCall() }
)
```

See the public initializer in `MessageComposer.swift` for optional configuration. Default colors, spacing, dimensions, type sizes, animation values, and press feedback come from [`../Resources/design-tokens.json`](../Resources/design-tokens.json) through `ComponentDesignPalette.warmEmber` and `ComponentDesignMetrics.warmEmber`; `Style.zping` uses those color tokens. Text, input, and action controls share one centered row in text mode, so their alignment comes from the SwiftUI layout rather than coordinate offsets. Pass a custom `Style` to adapt the component to another app. The component does not request microphone permission or perform network operations by itself.
