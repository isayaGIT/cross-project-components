# Gradient Background — Jade Sky

Experimental native SwiftUI port of the Jade Sky CSS gradient recipe from 21st.dev.

This component is kept in `Imports/background` for visual evaluation and is not yet promoted to the reusable production component catalog.

## Usage

```swift
ZStack {
    GradientBackground()

    // Foreground content
}
.frame(height: 440)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

- SwiftUI only; no third-party dependencies or image assets.
- The parent controls the component's size.
- The SwiftUI radial gradients approximate the original CSS gradient; compare visually before promoting it to a production component.

Source recipe: https://21st.dev/community/gradients/editor?from=85ea2692-591f-4b2b-928f-de88da3d1a88
