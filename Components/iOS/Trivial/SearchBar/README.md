# SearchBar

`SearchBar` is a reusable SwiftUI search control composed of three independently styled pieces: an outer capsule surface, a real editable `TextField`, and a dedicated search button. It owns layout and presentation only; filtering, networking, navigation, and result rendering remain the caller's responsibility.

## Basic use

```swift
@State private var query = ""

var body: some View {
    SearchBar(text: $query, placeholder: "Search") {
        performSearch(query)
    }
}
```

The search button calls `onSearch`. Pressing the keyboard's Search key calls `onSubmit` when supplied; otherwise it calls `onSearch` too.

## Independent styling

Pass `SearchBarCapsuleStyle`, `SearchBarFieldStyle`, and `SearchBarButtonStyle` to configure the outer surface, text input, and button separately. Each style accepts an `AnyShape` so custom shapes such as `RoundedRectSmoothed` can be supplied by the caller. The search action is rendered through the shared `ButtonCustom` component, which reuses `CapsuleButton` for its texture and border layers.

```swift
SearchBar(
    text: $query,
    placeholder: "Search stickers",
    capsuleStyle: SearchBarCapsuleStyle(
        shape: AnyShape(Capsule()),
        texture: .material(.ultraThin),
        border: .dashed(
            configuration: DashedLineConfiguration(
                lineWidth: 2,
                dashLength: 7,
                dashSpacing: 4,
                cornerRadius: 1
            ),
            color: .secondary.opacity(0.7)
        )
    ),
    fieldStyle: SearchBarFieldStyle(
        font: .system(size: 15),
        textColor: .primary,
        placeholderColor: .secondary
    ),
    buttonStyle: SearchBarButtonStyle(
        icon: AnyView(Image(systemName: "magnifyingglass")),
        iconColor: .primary,
        texture: .clear,
        size: CGSize(width: 40, height: 40)
    ),
    onSearch: { performSearch(query) }
)
```

## Surface and border options

- `SearchBarTexture.clear`, `.material(...)`, `.color(...)`, and `.custom(AnyView(...))` control the fill. Custom surfaces are clipped to the configured shape, so a project Liquid Glass view can be supplied without coupling this component to a specific glass package.
- `SearchBarBorder.none`, `.solid(...)`, `.dashed(...)`, and `.custom(AnyView(...))` configure the outline. Dashed outlines use the shared `DashedPath` / `DashedLineConfiguration` implementation and expose fill-coordinate and phase controls.
- The field texture defaults to `nil` (transparent), allowing the outer surface to show through. Its border defaults to `.none` to avoid a duplicate inner outline.
- The button defaults to a `magnifyingglass` icon, a transparent fill, no border, and a 38 × 38 point hit target.

## Focus and keyboard

An optional `FocusState<Bool>.Binding` can be passed as `focus` to let the caller control focus. Without it, the component uses private focus state and does not automatically claim or clear focus. The keyboard submit label defaults to `.search`. Text autocapitalization and autocorrection settings can be configured through `SearchBarFieldStyle`.

Decorative overlays and border views do not participate in hit testing. The text field expands into available horizontal space while the button retains its configured hit-target size; no screen width is hard-coded.
