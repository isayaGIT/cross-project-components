# ContainerStyle

A reusable directional fade or material treatment for container edges. It does not own layout, corner radius, or clipping; place it behind/over a container and choose the effect height.

```swift
ContainerStyle(height: 120, style: .black, direction: .bottomToTop)
ContainerStyle(height: 100, style: .blur, direction: .bottomToTop)
```

Styles: `.black` (black-to-transparent gradient), `.blur` (directionally masked ultra-thin material), `.color(Color)` (color fade), and `.gradient(Gradient)`. Directions: `.topToBottom`, `.bottomToTop`, `.leadingToTrailing`, `.trailingToLeading`.
