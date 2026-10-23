# VoiceMessage

A reusable SwiftUI voice-message player for chat messages, social comments, and feed content. One `VoiceMessageView` API supports two display modes while sharing the same playback engine.

## Display modes

- `VoiceMessageDisplayMode.compact`: minimal play control, speaker symbol, and duration. It intentionally does not show a waveform timeline or expose seeking.
- `VoiceMessageDisplayMode.waveform`: waveform timeline, elapsed/total time, and drag-to-seek interaction. While dragging, the progress and time bubble track the finger; the player seeks once when the gesture ends. VoiceOver users can adjust the timeline in small increments. No playback-speed control is included.

The host chooses the mode per context. Suggested defaults are `.compact` for private-chat bubbles and comments, and `.waveform` for standalone or longer audio content. The component does not automatically switch modes based on duration, preventing inconsistent layouts in a list.

## Usage

```swift
import SwiftUI

VoiceMessageView(
    audioURL: audioURL,
    displayMode: .compact,
    duration: 12,
    tint: .blue
)

VoiceMessageView(
    audioURL: audioURL,
    displayMode: .waveform,
    duration: 32,
    waveform: amplitudeSamples,
    tint: .blue,
    width: 280
)
```

`audioURL` can be a local file URL or a URL supported by `AVPlayer`. `duration` is optional and useful when duration is already available from the message model; otherwise, the component reads it from the media item. `waveform` accepts normalized bar heights in the `0...1` range. When waveform samples are absent, waveform mode renders a stable placeholder pattern; this is decorative and does not represent the actual audio amplitude.

## Responsibilities

The component owns play/pause, playback time, seeking in waveform mode, and player lifecycle. The host owns audio upload/download, caching, message models, sender layout, delivery state, and localization. Playback coordination across multiple independent `VoiceMessageView` instances is not global in this initial version; a host app that needs “only one voice plays at a time” should add a shared playback coordinator.

Requirements: Swift 5.9+, iOS 17+ (matching the root package deployment target).
