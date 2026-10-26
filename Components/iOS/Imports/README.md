# Imports

Third-party components imported from SwiftPieces and other upstream sources. These are kept separate from the project's native components because they have not necessarily been integrated or adapted to the local component APIs.

- `SwiftPiecesOriginals/`: imported SwiftPieces source files, grouped by component category.
- `TabBar/GlassSegments/`: imported Glass Segments component intended for tab-bar-related exploration.
- `OpenShaders/`: upstream OpenShaders repository snapshot plus a native SwiftUI/Metal port of the supplied `@isaya` shader; see `OpenShaders/SwiftUI/README.md` for the source-availability caveat and usage.

Review each component's source header and license before modifying or redistributing it. Asset folders include a README when the upstream page did not expose a downloadable preview animation.
- Shaders/: original WebGPU shader sources and platform-specific migrations, kept separate from reusable component implementations.
- `Timeline/有刻度的 Timeline/`: compiled browser-source reference for the tick-marked timeline from pengzhe.ng, with source provenance and preview notes. It is not yet a standalone component; see its README.
- `Card/CardStacks/DepthCarousel/`: original React Bits Depth Carousel source (TypeScript + CSS), registry snapshot, and license; kept as a reference import, not part of the native iOS build.
