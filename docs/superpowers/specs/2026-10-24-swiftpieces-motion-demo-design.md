# SwiftPiecesMotionDemo — Motion Playground

## Status

Approved for implementation by the user on 2026-10-24. This is a personal-use, non-distributed repository and demo. The prototype uses the official SwiftPieces CLI output and retains the source-file copyright/license notices and provenance.

## Goal

Provide one isolated iOS Simulator app in which the user can open and interactively compare seven Swift Pieces motion components: `FlipCard`, `ParallaxCard`, `TextReveal`, `StatusMorph`, `DragToDismiss`, `DepthCarousel`, and `Silk` (including `Silk.metal`). This is an exploration playground, not a production integration; do not modify production chat, profile-card, or message-bubble behavior.

## Structure

- Imported upstream source files and `Silk.metal` live under `Components/iOS/Imports/SwiftPiecesOriginals/MotionPlayground/`, organized by upstream category.
- The independent XcodeGen app lives at `Demos/SwiftPiecesMotionDemo/`, follows the repository's existing `project.yml` pattern, and directly includes the imported source files without changing them.
- Add only a narrow `.gitignore` allowlist for this demo; do not alter other ignore rules.
- Preserve upstream copyright/license headers and document source URLs, version, iOS minimum, and resource/permission notes in the import README.

## Demo experience

- A navigation list exposes all seven components; each screen can return to the list without sharing preview state.
- `FlipCard`: tap/drag flip with clearly distinct front and back.
- `ParallaxCard`: layered image/caption card with a press interaction.
- `TextReveal`: replay button and controls for representative reveal presets/units.
- `StatusMorph`: interactive idle/loading/success/failure state selection.
- `DragToDismiss`: draggable sample presentation and restore/reopen path.
- `DepthCarousel`: multiple sample pages, swipe/selection, and depth recession.
- `Silk`: animated Metal background with readable foreground controls; `NSMotionUsageDescription` is included for the optional tilt-light feature.

## Integration and safety constraints

- Imported Swift/Metal files must remain faithful to the official CLI output. Keep copyright and license text intact.
- The user has stated this project is personal and will not distribute source. Do not publish or redistribute imported component source. Do not attempt to bypass a paid-access gate; record CLI behavior and any unresolved entitlement requirement accurately.
- No production integration, unrelated cleanup, resets, or automatic Git commits. Preserve all pre-existing worktree changes.

## Validation

- Generate the demo Xcode project with XcodeGen and build for an available iOS Simulator.
- Install and launch the app on the already-available iPhone 17 Pro simulator where possible.
- Verify each of the seven screens opens, primary interaction is accessible, and navigation can return to the list without a crash. Use UI automation or explicit interaction evidence rather than treating a successful compile as sufficient.
- Inspect the build output for missing Metal resources, unsupported deployment targets, and unresolved imports.

## Acceptance criteria

- One standalone demo app lists and previews all seven effects.
- Imported components retain source headers and have a provenance README.
- The demo is tracked by the repository's existing conventions, with no broad ignore-rule changes.
- All existing user changes remain untouched and there is no automatic commit.
- Report build/launch and per-component interaction verification, including any partial failures.
