# Motion Config Protocols

Shared, compile-time contracts for reusable component motion settings.

## First validation: BottomSheet

- `MotionConfigProtocol` defines the shared backdrop-animation requirement.
- `BottomSheetMotionConfigProtocol` adds the sheet-animation requirement.
- `StandardBottomSheetMotionConfig` is the default implementation used by `BottomSheetPresentationConfiguration`.

The `OverlayPresenter` consumes these values. Animation tuning therefore happens in the config implementation rather than as hard-coded modifiers inside the presenter. A call site can opt into another implementation by passing it through `BottomSheetPresentationConfiguration(motion:)`.

```swift
let motion = StandardBottomSheetMotionConfig(
    sheetAnimation: .interactiveSpring(response: 0.4, dampingFraction: 0.9),
    backdropAnimation: .easeInOut(duration: 0.25)
)

let configuration = BottomSheetPresentationConfiguration(motion: motion)
```

This folder is compiled as part of the existing `CrossProjectComponentsIOS` target. It is intentionally not a separate Swift package during this first experiment, to keep the test focused on whether the protocol/config pattern improves the existing component.
