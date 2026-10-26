# CoverFlow One

Native SwiftUI adaptation of Ruixen UI's Coverflow Carousel, kept separate from the source implementation.

- `Original TypeScript Code/coverflow-carousel.tsx`: verbatim upstream component source.
- `Original TypeScript Code/registry.json`: complete registry metadata and source payload.
- `Sources/CoverFlowCarousel.swift`: native SwiftUI component source (mirrored into the Animated SwiftPM target at `../Sources/Animated/CoverFlowCarousel.swift`).

## API

Use `CoverFlowSlide(id:image:accessibilityLabel:title:subtitle:metadata:)` to provide content and `CoverFlowCarousel(slides:...)` to configure the carousel. Default geometry follows the upstream values: rotate 44°, depth 0.6 card widths, perspective 3 card widths, falloff 0.56, fade 0.1 and gap 0.05.

## Parity notes

The React source uses direct DOM transforms and requestAnimationFrame for its exponential settling. SwiftUI uses native 3D transforms and an ease-out animation; exact frame-by-frame motion may differ from the browser implementation. Compare against the upstream browser preview before claiming pixel-perfect parity. Image inputs are native SwiftUI `Image` values so callers control loading and caching.

## Upstream

- https://21st.dev/community/components/s/carousel?qt=card-carousel%2Ccarousel%2Cfeature-carousel&qs=bookmarks&preview=%2F%40ruixen.ui%2Fcomponents%2Fcoverflow-carousel
- https://ruixen.com/docs/components/coverflow-carousel
- https://ruixen.com/r/coverflow-carousel
