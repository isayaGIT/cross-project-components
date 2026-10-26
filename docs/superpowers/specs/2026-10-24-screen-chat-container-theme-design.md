# ScreenChatContainer Theme Architecture

## Status

Design approved in conversation on 2026-10-24. This document records the approved scope before implementation. It is not an implementation or migration record.

## Goals

- Make `ScreenChatContainer` the single owner of the complete active theme and of theme selection.
- Expose public, area-based appearance configuration so host apps can customize all colors for the container shell, theme button, sidebar, and chat screen.
- Make each built-in preset update all areas consistently.
- Keep the container reusable and independent of chat models, persistence, networking, and application-specific sidebar content.
- Preserve source compatibility where practical and document any unavoidable API migration.

## Non-goals

- Do not change chat behavior, message persistence, navigation/business actions, or sidebar data ownership.
- Do not force the generic container to inspect or style arbitrary host-provided view internals.
- Do not introduce a global semantic-token layer; the selected API is area-based configuration objects.

## Public theme model

Introduce a public `ScreenChatContainerTheme` value that aggregates four independently configurable areas:

1. `container`: shell background/content surface, border/separator, scrim/overlay, and any shell-specific visual treatments currently hard-coded in `ScreenChatContainer`.
2. `themeButton`: symbol foreground, button background, pressed/interaction appearance, and accessibility-independent visual styling. Geometry stays in the view unless a concrete need to configure it is demonstrated.
3. `sidebar`: a public `SidebarAppearance` with nested area configurations for background; header title/icon/new-conversation control; search field background/text/icons/border; section headings; conversation row default/selected surfaces and primary/secondary text; separator; footer. Add fields based on real rendered sidebar elements rather than speculative generic tokens.
4. `screenChat`: the existing `ScreenChatConfig`, preserving its detailed Header, message, avatar, composer, and typography settings.

Configuration types should expose public initializers with defaults and public properties appropriate for caller customization. The theme should be a value type, allowing hosts to derive a preset and override one area without mutating unrelated areas. Keep the existing `ScreenChatConfig` as the dedicated chat-screen sub-configuration rather than duplicating its fields.

## Ownership and data flow

`ScreenChatContainer` owns the current `ScreenChatContainerTheme` and the theme picker presentation state. Built-in theme selection replaces the active theme as one value. The selected preset supplies complete defaults for all four areas. A host-provided theme initializes the container; if host customization from a preset is needed, expose preset factory values that can be copied and modified before being passed in.

The container applies `container` and `themeButton` directly. It passes `sidebar` appearance explicitly to supported library sidebar components and passes `screenChat` configuration to `ScreenChat`. Theme selection must not mutate a private theme state inside `ScreenChat`; remove its legacy independent preset selection path. `ScreenChat` remains responsible for rendering chat UI using the supplied `ScreenChatConfig`.

The container accepts a generic host-provided `Sidebar: View`, so it cannot automatically recolor arbitrary child views. The library's own `Sidebar` component and `SidebarSettingsEntry` must adopt the public sidebar appearance API. Document that custom host sidebar implementations must consume the provided appearance themselves. Keep the container's sidebar closure generic and avoid runtime introspection or environment-based implicit styling that silently couples unrelated views.

## Presets

Keep the existing System, Midnight, Ocean, Rose, and Forest choices. Move preset ownership and selection to `ScreenChatContainerTheme` / container theme-picker logic. Each preset must provide coordinated values for container shell, theme button, sidebar, and `ScreenChatConfig`. Theme preview swatches should represent the overall preset accent. System appearance may continue respecting the current light/dark color scheme; explicit color presets should be stable and coherent in both supported schemes where current APIs allow.

## API compatibility

The container currently exposes builder closures for sidebar and content, and the recent change passes a theme-picker `Binding` through the content closure. Avoid further positional-parameter growth. Prefer a stable container initializer with `theme: ScreenChatContainerTheme = .system(...)` (or an equivalent documented factory) and a content API that gives `ScreenChat` its child config without making the container depend on `ScreenChat` as a concrete type. Retain existing initializer overloads where possible; deprecate old theme-binding plumbing if needed rather than breaking all callers at once. Check all repository call sites before finalizing overloads.

`ScreenChat` should retain a configuration-taking initializer. Its old theme picker binding may be deprecated for a transition or removed if the repository's API policy and call-site audit show it is safe. The active theme-selection UI belongs to the container, not `ScreenChat`.

## Files in scope

- `Components/iOS/Integrated/ScreenChatContainer/ScreenChatContainer.swift`
- New public theme/appearance model(s) under `Components/iOS/Integrated/ScreenChatContainer/`
- `Components/iOS/Trivial/Sidebar/Sidebar.swift`
- `Components/iOS/Integrated/ScreenChatContainer/SidebarSettingsEntry.swift`
- `Components/iOS/Integrated/ScreenChat/ScreenChat.swift`
- `Components/iOS/Integrated/ScreenChat/ScreenChatThemes.swift` and `ScreenChatConfig.swift` as needed to separate preset ownership from chat appearance data
- `Demos/ScreenChatDemo/Sources/ScreenChatDemoApp.swift`
- `Components/iOS/Integrated/ScreenChatContainer/README.md` and relevant component documentation

Do not overwrite unrelated existing user changes in the working tree. In particular, the current worktree contains edits outside this feature; preserve them.

## Verification and acceptance criteria

1. The project builds for the existing iOS simulator destination.
2. All five presets change the container shell, theme button, library sidebar, and chat screen together.
3. A caller can customize a single sidebar area (for example, selected-row background) while retaining all other values from a preset.
4. Sidebar header, search, section label, rows, selected state, separators, and footer consume their respective appearance fields; no current hard-coded sidebar color remains for those configurable areas.
5. A custom host sidebar is not falsely claimed to be automatically themed; the public closure/API documentation explains how to pass and consume its appearance.
6. `ScreenChat` has no independent selected-preset state that can override the container's theme. It renders from the supplied `ScreenChatConfig`.
7. Existing in-repository call sites compile; any public source-compatibility break is minimized and documented.
8. Run the existing demo build and inspect the resulting UI when available.

## Risks and mitigations

- Generic sidebar content cannot be recolored by the container automatically. Mitigation: explicit appearance parameter for library components and clear host integration contract.
- Theme state passed via an ever-growing closure signature becomes brittle. Mitigation: stabilize the initializer and use typed configuration rather than adding more unrelated closure parameters.
- Existing theme model may mix preset identity with detailed colors. Mitigation: separate preset identity/preview metadata from the actual composed configuration and keep `ScreenChatConfig` as the chat sub-configuration.
- Other worktree edits may be unrelated. Mitigation: inspect diffs before every edit and limit changes to the scoped files.
