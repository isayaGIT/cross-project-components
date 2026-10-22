# LineDashed Implementation Plan

Date: 2026-10-22
Design: `docs/superpowers/specs/2026-10-22-line-dashed-design.md`
Status: Approved to proceed

## Repository constraints

- Preserve all unrelated user changes. Do not reset, checkout, clean, or stage unrelated files.
- Keep `Shapes/LineDashed` as the independent package source of truth.
- Before root integration, inspect the existing `RoundedRectSmoothed` source/package structure and select a dependency direction that avoids duplicate implementation and circular dependencies.
- The root package currently targets iOS 17 and macOS 13; verify actual SwiftUI APIs against these deployment targets.
- The user-selected Showcase is a standalone app. Keep it isolated from existing demos.
- Make small, reviewable commits containing only LineDashed-related files.

## Phase 1 — Package skeleton and configuration

1. Add `Shapes/LineDashed/Package.swift` with iOS 17 and macOS 13 targets and no external dependencies.
2. Add public configuration types for dash width, length, spacing, corner radius, and closed-path distribution.
3. Normalize non-finite and invalid numeric inputs in one place.
4. Add the initial test target and tests for defaults, normalization, and closed/open path mode values.
5. Run `swift test --package-path Shapes/LineDashed`.

Acceptance: standalone package resolves and builds on the current toolchain; configuration tests pass.

## Phase 2 — Arc-length path engine and dash layout

1. Define an internal geometry value for each segment (center, tangent angle, length, width, effective radius, path-distance interval).
2. Implement path flattening/sampling with a documented tolerance and robust handling of degenerate elements.
3. Generate dash placements by distance along the flattened path, interpolating position and tangent.
4. Implement open path layout and closed-path automatic even distribution.
5. Implement closed-path fixed dash length/spacing mode and animation phase offset.
6. Add geometry tests for straight paths, corners, cubic curves, closed rectangles, degenerate/empty paths, radius clamping, and stable dash/gap distribution.

Acceptance: predictable segment positions and orientations with bounded sampling error; no non-finite geometry.

## Phase 3 — SwiftUI drawing and fill coordinate modes

1. Add the public `LineDashed` SwiftUI view accepting a path and configuration.
2. Add rectangle and rounded-rectangle convenience initializers/builders.
3. Render independent rounded-rectangle segments using centralized drawing where possible.
4. Implement solid color and linear/radial/angular gradient fills.
5. Define stable path-global versus per-segment fill coordinates; ensure segment transforms do not accidentally restart a continuous gradient.
6. Add checkerboard and grid pattern renderers behind an extensible fill/pattern interface.
7. Add render behavior tests where testable and visual fixtures/examples for coordinate modes.

Acceptance: API compiles and continuous/per-segment fill semantics are demonstrably distinct and correct.

## Phase 4 — Material adapters and opt-in animation

1. Add platform-gated system material and Liquid Glass adapter paths.
2. Provide safe fallback behavior for unsupported platforms/OS versions.
3. Implement static-by-default dash-flow animation by adjusting phase/offset without restarting path sampling every frame.
4. Verify no timer/continuous update is active in static mode.
5. Run iOS and macOS compile checks for the package.

Acceptance: platform-specific code is isolated; normal rendering remains available regardless of glass support.

## Phase 5 — Standalone Showcase App and documentation

1. Create an isolated `Examples/LineDashedShowcaseApp` project.
2. Add interactive controls for path type, line width, dash length, spacing, corner radius, closed-path mode, fill type, fill coordinate mode, and animation toggle/speed.
3. Include examples for straight, rectangle, rounded rectangle, arc, and curved/custom path.
4. Write README with installation, API examples, supported platforms, normalization rules, fill modes, materials, limitations, and tests.
5. Build and launch the Showcase App in an available simulator/runtime when available.

Acceptance: showcase builds independently and every public first-version feature can be inspected interactively.

## Phase 6 — Main repository integration

1. Choose a single-source package boundary for sharing `RoundedRectSmoothed` if needed; do not create a circular dependency.
2. Add a local package dependency/product to the root `Package.swift`, avoiding a duplicate target over the same sources.
3. Resolve and build the root package.
4. Run targeted LineDashed tests and relevant existing tests without modifying unrelated components.
5. Inspect `git diff --check` and `git status --short`; ensure only LineDashed-related changes are included in the commit.

Acceptance: both standalone package and root package consume the same implementation and tests pass.

## Validation commands

- `swift test --package-path Shapes/LineDashed`
- `swift build --package-path Shapes/LineDashed`
- `swift test` at repository root
- `swift build` at repository root
- Xcode project build for Showcase on available iOS simulator
- macOS target compile check where available
- `git diff --check`

If an environment or platform SDK is unavailable, report the exact limitation and do not claim the check passed.

## Implementation order

Complete phases 1–3 with tests before adding materials and animation. Do not begin the Showcase or root integration until the core API and geometry tests are stable. Keep commits scoped to LineDashed and never include unrelated user modifications.

