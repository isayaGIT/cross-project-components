# InteractiveAssets Protocol

Language-neutral, versioned content contracts for StickerPack, individual stickers, animated message bubbles, and fullscreen animations. The protocol is separate from AssetServer: AssetServer distributes bytes and placement/catalog information; this protocol defines what the downloaded content means.

## Contract layers

1. **Transport / integrity** — AssetServer currently supplies asset IDs, content types, sizes, SHA-256 and download URLs. This protocol's manifest describes a logical content bundle and the files it references. An integration adapter must map AssetServer's `id`, `contentType`, `size`, and `sha256` fields to `AssetFile.id`, `mediaType`, `byteCount`, and `sha256`.
2. **Content schema** — JSON Schema files under `Schemas/` are the language-independent source of truth. The Swift package is a typed iOS implementation of those wire contracts, not a replacement for schema validation on the server.
3. **Runtime contract** — renderers are named capabilities (`gif`, `lottie`, `nine-patch-frames`, etc.). A client must reject or safely skip content requiring an unsupported renderer rather than guessing.

## Versioning rules

- `protocolVersion` describes the schema/field semantics. This initial release is `1.0`.
- `contentVersion` / per-type `version` describes an individual published item and may change independently of the protocol.
- IDs are stable opaque strings. Never use display names, list indexes, or filesystem paths as IDs.
- `AssetReference.assetID` must resolve to exactly one file declared by the bundle manifest. It is not a URL or path. All referenced IDs must exist; IDs must be unique within a manifest.
- SHA-256 is computed over exact downloaded bytes. Verify it before making a file available to a renderer.
- Time values explicitly named `durationMs` are milliseconds. NinePatchStudio v1's `duration` and `totalDuration` retain their existing seconds semantics for backwards compatibility.
- Layout dimensions and offsets in the interactive bubble schema are logical points. Insets and dimensions must be finite and non-negative; decoration width/height must be positive.
- Asset filenames are leaf names only. Resolve files through the manifest ID map, never by concatenating untrusted path strings.
- Unknown `protocolVersion` means the client must not attempt to render the document. Unknown optional fields should only be ignored where the schema permits them; current schemas intentionally reject undeclared fields to catch drift early.
- Remote documents configure already-shipped renderers; they are not executable code. Do not evaluate downloaded scripts or treat JSON as Swift code.

## Existing implementation alignment

- `Class/Sticker/Sticker.swift`: stable sticker IDs, pack relationship and tags map to `StickerEntry` identity/metadata.
- `Class/Sticker/StickerLibrary.swift`: catalog identity and ordered `packIDs` map to `StickerLibraryDocument`.
- `Class/Sticker/StickerPack.swift`: pack identity, name, tags, version, ordered membership and publisher metadata map to `StickerPackDocument`. The protocol embeds entries so a published pack is a self-contained catalog document; an adapter can continue persisting the existing normalized ID-based models.
- `Class/Sticker/StickerAsset.swift`: `MediaType` and dimensions inform the asset file metadata. Runtime file location remains storage-owned and is not serialized as an arbitrary URL.
- `Components/iOS/MessageBubble/MessageBubbleTheme.swift`: `LottieDecoration` placement, size, alignment, offset and loop mode map to `BubbleDecoration`; alignment strings need an explicit allow-list adapter.
- `Components/iOS/MessageBubble/NinePatchFrameAnimation.swift` and `dependencies/NinePatchStudio`: the existing `ninepatch-studio/animation-v1` format is preserved by its own schema and `NinePatchAnimationExport` model. Frame-by-frame durations are retained. A renderer adapter still has to resolve the exported frames into local resource names/URLs.
- `Infrastructure/AssetServer/sample`: remains the transport/distribution sample. It is not yet validating these content schemas or exposing bundle-level publishing APIs.

## Schema files

- `asset-manifest.schema.json`: bundle file inventory and integrity metadata.
- `sticker-library.schema.json`: discoverable index of pack IDs, matching the existing `StickerLibrary` concept.
- `sticker-pack.schema.json`: a distributable ordered pack with embedded sticker entries.
- `sticker.schema.json`: a standalone sticker document.
- `animated-message-bubble.schema.json`: background/decorations/layout/renderer configuration.
- `fullscreen-animation.schema.json`: media, playback, trigger, content mode, optional audio and parameters.
- `ninepatch-studio-animation-v1.schema.json`: compatibility contract for current NinePatchStudio output.

## Important integration gap

The schemas and Swift models establish the first protocol draft. Production conformance still requires a server-side JSON Schema validator, cross-reference validation (every referenced asset ID exists), duplicate-ID checks, renderer-specific validation, and adapter tests that map protocol documents into the existing Swift views. JSON Schema alone cannot prove that the iOS renderer can play a specific asset or that all referenced files are present.

## Complete material bundle upload (Asset Manager)

Asset Manager publishes one logical material per request through `POST /api/v1/apps/{app}/versions/{version}/interactive-bundles`. Send multipart form data with exactly one field named `bundle`, containing a ZIP archive with this layout:

- `content.json`: exactly one content document validated against the schema for the declared content type.
- `asset-manifest.json`: bundle inventory validated against `Schemas/asset-manifest.schema.json`.
- `files/<fileName>`: exactly one archive entry for every file declared in the manifest.

File IDs and names must be unique, sizes and SHA-256 values must match, and manifest file IDs must exactly equal the asset references in the content document. Extra files, missing files, unsafe paths, duplicate names, or mismatches reject the entire upload. The existing single-file `/api/v1/assets` endpoint remains for display-slot assets and is not a way to publish an interactive material.

For Asset Manager bundle publishing, every property declared by the selected content schema must be present, including properties marked optional in the v1 schema. This strict completeness rule prevents configuration omissions. Values must currently satisfy the field's schema; explicit null is not accepted unless the schema allows it. If a field cannot be meaningfully supplied, update the protocol to define explicit nullability/default semantics in a versioned schema change rather than silently omitting it.
