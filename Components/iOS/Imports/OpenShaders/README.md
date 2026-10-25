# OpenShaders import

- `Source/OpenShadersOriginal.webgpu.js` — original `@isaya` WebGPU/WGSL module supplied for this task, preserved as a reference.
- `SwiftUI/OpenShadersView.swift` — native SwiftUI + MetalKit port of the same shader math, plus `OpenShadersDemoView` for the component showcase.
- `LICENSE` and `.github/assets/openshaders-header.png` — upstream repository files.

## Upstream status

The cloned upstream repository currently contains its README, MIT license, and branding asset. Its README says the full platform source is forthcoming; the WebGPU module in `Source/` is the supplied shader code, not a file obtained from the current repository tree.

## Use

```swift
OpenShadersView(theme: .system)
    .frame(height: 280)
```

The renderer is native Metal, continuously animated, and supports `.dark`, `.light`, or `.system` themes plus custom dark/light background colors. It is designed to compile into `CrossProjectComponentsIOS` on iOS and can also be added directly to the `ComponentShowcase` target.
