# Banner

A lightweight SwiftUI notice with a background, border, optional leading icon, multiline text, and up to two actions.

## Usage

```swift
Banner(
    text: "Your changes have been saved.",
    icon: Image(systemName: "checkmark.circle.fill"),
    actions: [
        BannerAction("Undo", systemImage: "arrow.uturn.backward") {
            undoChanges()
        },
        BannerAction("Details") {
            showDetails()
        }
    ]
)
```

## Action layout

- `.vertical` (default): actions stack vertically on the trailing edge.
- `.horizontal`: actions sit side-by-side on the trailing edge.
- `.bottom`: actions sit side-by-side below the content.

With no actions, the action area is omitted. With no icon, the text uses the available content width. The text wraps naturally and determines the banner height. Passing more than two actions triggers a precondition failure.

Text typography (`textFont`, `textFontSize`), icon size/color (`iconSize`, `iconColor`), action font (`actionFont`), background, foreground, border color/width, corner radius, and content padding are configurable. `textFontSize` overrides `textFont` when provided. The host controls presentation and dismissal.

`iconColor: Color?` optionally sets the leading icon tint independently of the banner text. When omitted, the icon inherits `foreground`. `icon` itself is optional (`nil` hides it). Each `BannerAction` takes its own `action` closure; each button invokes its corresponding closure when tapped.
