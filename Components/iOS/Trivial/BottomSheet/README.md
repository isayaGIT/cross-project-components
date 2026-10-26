# OverlayPresenter

A shared presentation host for dimmed overlays and bottom sheets. It owns backdrop rendering, z-order, presentation state, and backdrop dismissal. The backdrop is integrated into the presenter; content components should not add a separate `GrayOverlay`.

For a bottom sheet:

```swift
OverlayPresenter(
    isPresented: $isPresented,
    configuration: .init(height: .fraction(0.72), showsGrabber: true)
) {
    ThemePickerContent()
}
```

For a custom-positioned overlay (for example, a calendar):

```swift
OverlayPresenter(
    isPresented: $isPresented,
    backdrop: .black.opacity(0.22)
) {
    CalendarContent()
}
```

Custom overlay content controls its own layout. The presenter supplies the dimming layer behind it and places it above the backdrop. Bottom-sheet content retains the existing height, drag, grabber, background, border, and corner-radius configuration. `@Environment(\.dismissBottomSheet)` remains available for existing sheet content.

`BottomSheetPresenter` remains as a source-compatibility type alias; new call sites should use `OverlayPresenter`.
