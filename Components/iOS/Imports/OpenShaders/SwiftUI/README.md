# Native SwiftUI/Metal port

`OpenShadersView` translates the supplied OpenShaders `@isaya` WebGPU shader to Metal Shading Language. The implementation preserves its 82-layer iterative warp/fold field, OKLCH-derived color, animated flow/breathing, vignette, tone mapping, and temporal dithering. It is rendered per frame on the GPU rather than using a video or static image.

```swift
OpenShadersView(theme: .system)
    .frame(height: 280)
    .clipShape(RoundedRectangle(cornerRadius: 24))
```

`OpenShadersDemoView()` is included as a quick showcase with dark/light/system theme switching.

Pixel parity is algorithm-level at this stage; WebGPU and Metal may differ slightly in floating-point precision, rasterization conventions, and display color management. The official OpenShaders site/editor implementation is not in the current upstream repository snapshot, so this port targets the supplied shader rather than recreating the unavailable website UI.
