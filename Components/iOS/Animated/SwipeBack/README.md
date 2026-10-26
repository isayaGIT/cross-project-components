# SwipeBack (iOS)

A portable package extraction of the modifier used by ZPing on chat and file overlays (`ZPing/src/ui/components/gestures/screen_chat/SwipeBackModifier.swift`). This is the app's real edge-swipe modifier, not the previous AI-authored `SwipeBack` container.

```swift
import CrossProjectComponentsIOS

DetailScreen()
    .swipeBack(isPresented: $isPresented, scrollDisabled: $isScrollDisabled)
```

It keeps the source interaction's leading-edge recognition, horizontal-vs-vertical classification, simultaneous gesture handling, spring settle, haptic feedback, and dismissal binding. Thresholds can be configured. Use normal `NavigationStack` back navigation where it already provides the required experience; this modifier is intended for custom overlay/navigation transitions.
