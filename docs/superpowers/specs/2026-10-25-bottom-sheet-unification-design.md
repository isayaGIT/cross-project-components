# BottomSheet Unification Design

## Goal

Replace the current mixture of a vendored BottomSheet package, a `SheetCustom` adapter, direct `.bottomSheet` modifiers, and native `.sheet` presentation with one reusable `BottomSheet` component located at `Components/iOS/Trivial/BottomSheet`.

The shared component owns sheet presentation mechanics: visibility synchronization, sizing, backdrop dismissal, drag dismissal, grabber styling, background, corner radius, and optional top border decoration. Call sites continue to own their content and domain-specific state.

## Current State

- The vendored `lucaszischka/BottomSheet` Swift package is stored at `Components/iOS/Trivial/SheetConfig`, but its package product and target are already named `BottomSheet`.
- `Components/iOS/Trivial/SheetCustom/SheetCustom.swift` wraps that package and exposes `SheetCustomHeight`, `SheetCustomConfiguration`, and `SheetCustom`.
- Sticker Search and ComposeSection use the underlying `.bottomSheet` modifier directly and each maintain presentation state.
- Theme Picker and Apps use SwiftUI `.sheet` with medium/large detents.
- The settings screen preview still references `SheetCustom`.
- Package references exist in the root `Package.swift`, StickerKeyboardDemo's project generator config, and its generated Xcode project.

## Design

### 1. Standalone package location

Move the existing vendored package intact from `Components/iOS/Trivial/SheetConfig` to `Components/iOS/Trivial/BottomSheet`. Preserve upstream implementation files and `Media.xcassets`; do not rewrite vendored internals as part of the move. Keep the Swift package product/module name `BottomSheet` so source imports remain stable. Update every local package path, exclusion, README reference, generated project reference, and demo package declaration from `SheetConfig` to `BottomSheet`.

### 2. Reusable presentation component

Add a first-party SwiftUI `BottomSheet` view in the new package alongside the vendored engine. It accepts a `Binding<Bool>`, a configuration value, and arbitrary `@ViewBuilder` content. Configuration supports a target height (fraction or points), surface/background customization, optional top border line, border color/width, backdrop color, corner radius, grabber visibility, and backdrop/drag dismissal.

The component is the single first-party place that adapts a boolean presentation binding to the underlying library's `BottomSheetPosition`. Dismissal via backdrop or drag updates the binding; changing the binding externally presents or hides the sheet. Keep defaults conservative and match the existing `SheetCustom` behavior unless a call site explicitly needs different sizing or appearance.

### 3. Remove SheetCustom

Delete the `SheetCustom` source and remove `SheetCustomHeight`, `SheetCustomConfiguration`, and `SheetCustom` from the public API. Replace the preview use in `SheetSettingsChatSettings` with `BottomSheet`. Audit the entire repository for references and remove stale imports, docs, package exclusions, and paths.

### 4. Migrate call sites

- **Theme Picker:** replace native `.sheet` with `BottomSheet`; preserve the existing navigation/list content and selection behavior. Map the existing medium/large intent to a sensible shared-component height, keeping explicit dismissal after selecting a theme or tapping Done.
- **Apps panel:** replace native `.sheet` with `BottomSheet`; preserve `SheetApps` selection callback and current medium/large intent with an appropriate shared height.
- **Sticker Search:** remove its direct `.bottomSheet` presentation/state adapter and host its existing search content inside `BottomSheet`; preserve the public `StickerSearchSheet(isPresented:configuration:onSearch:)` initializer and its current default 90% height, search history, pack selection, and callbacks.
- **ComposeSection:** replace the direct `.bottomSheet` modifier with `BottomSheet`, preserving capsule selection, 62% default height, and clearing the active capsule when dismissed.
- **Settings preview:** render the existing settings content inside `BottomSheet`.

Do not unify the contents of these sheets or alter unrelated UI. Avoid nested sheet engines and avoid duplicate presentation state synchronization at call sites.

## State and Dismissal Behavior

The shared component must cover these cases:

1. `isPresented` changes from false to true: show at the configured position.
2. `isPresented` changes from true to false: hide the sheet.
3. User dismisses via backdrop or drag: update `isPresented` to false.
4. Content is replaced while the sheet remains presented: do not spuriously dismiss it.
5. A call site reopens the sheet after dismissal: it must return to the configured position.

The underlying package remains responsible for gesture mechanics and animation. The wrapper is responsible only for adapting the API and centralizing common defaults.

## Validation

- Build the standalone BottomSheet package on the host platform and, where supported, for iOS Simulator.
- Build the root Swift package and StickerKeyboardDemo after updating package paths.
- Run any relevant tests and compile checks.
- Search for `SheetConfig`, `SheetCustom`, and direct `.bottomSheet(` call sites to ensure only intentional engine internals remain.
- Do not modify unrelated existing worktree changes. The known independent `ProfileCard.swift` compile error (`profile.status.defaultColor`) should be reported if it blocks a full app build, not fixed as part of this change.

## Non-Goals

- Rewriting or forking the upstream BottomSheet gesture engine.
- Changing sheet content, search behavior, theme semantics, or app selection semantics.
- Fixing unrelated compile errors or cleaning unrelated worktree state.
