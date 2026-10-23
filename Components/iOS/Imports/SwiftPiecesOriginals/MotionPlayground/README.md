# SwiftPieces Motion Playground imports

These eight source files were obtained through the official SwiftPieces CLI (`npx swiftpieces add FlipCard ParallaxCard TextReveal StatusMorph DragToDismiss DepthCarousel Silk`) on 2026-10-24. The files retain the upstream copyright and MIT + Commons Clause notice in each source file. Upstream source of truth: <https://github.com/Saivion/SwiftPieces/tree/main/registry/swift>.

| Piece | Local source | Upstream source | Upstream version | Runtime/resource notes |
|---|---|---|---|---|
| FlipCard | `Cards/FlipCard.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/cards/FlipCard.swift> | 2.2.0 | iOS 17+ |
| ParallaxCard | `Cards/ParallaxCard.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/cards/ParallaxCard.swift> | 2.2.0 | iOS 17+ |
| TextReveal | `Text/TextReveal.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/text/TextReveal.swift> | 2.2.0 | iOS 17+ |
| StatusMorph | `Feedback/StatusMorph.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/feedback/StatusMorph.swift> | 2.2.0 | iOS 17+ |
| DragToDismiss | `Motion/DragToDismiss.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/motion/DragToDismiss.swift> | 2.2.0 | iOS 17+ |
| DepthCarousel | `Lists/DepthCarousel.swift` | <https://github.com/Saivion/SwiftPieces/blob/main/registry/swift/lists/DepthCarousel.swift> | 2.2.0 | iOS 17+ |
| Silk | `Backgrounds/Silk.swift`, `Backgrounds/Silk.metal` | <https://github.com/Saivion/SwiftPieces/tree/main/registry/swift/backgrounds> | 2.2.0 | iOS 17+; Metal shader required. Motion permission string is present in the demo target. |

The demo uses the official CLI output and does not alter the imported implementations. `FlipCard`, `ParallaxCard`, `TextReveal`, and `StatusMorph` carry upstream `pro` metadata in the registry source headers; the CLI completed this fetch without requiring a key in this environment. No entitlement check was bypassed, and this note records the observed access behavior rather than asserting account entitlement.

The upstream MIT + Commons Clause notice permits use as part of an application/product but restricts selling, sublicensing, or redistributing the components themselves, whether alone, bundled, or ported. This is a personal, non-distributed project. Do not publish or redistribute these source files without reviewing the current license and obtaining any required permission.
