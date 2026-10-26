# ScreenChat Theme Protocol: Required Colors and Fonts

## Status

Design draft for user review. This document extends the existing ScreenChatContainer theme architecture; implementation has not started.

## Goal

Introduce a public Swift protocol that constrains theme definitions, not UI components. Every complete ScreenChat theme must explicitly provide the required visual colors and fonts for the major components and their meaningful subcomponents. The contract is organized into exactly two top-level sections: `Colors` and `Fonts`.

## Principles

1. `ScreenChatThemeProviding` is a contract for theme values. `SearchBar`, `Sidebar`, `ScreenChat`, `StickerKeyboard`, and other Views do not conform to it.
2. Components consume narrowly scoped appearance/configuration values for their own rendering. They must not need to know the full theme protocol or the container's theme-selection state.
3. Required theme values have no silent system-color or font fallback. A theme factory must provide every required value explicitly. Defaults may remain on standalone component APIs for backward compatibility, but a complete container theme cannot rely on them to fill missing required theme tokens.
4. Organize values by component/subcomponent, not by generic color roles. A maintainer should be able to find a SearchBar token under its containing Sidebar/SearchBar group, or a message bubble token under MessageChunk.
5. Each visual property has one authoritative source. Existing `ScreenChatConfig`, `SidebarAppearance`, `StickerKeyboard.Configuration`, `InputActionPanel.Configuration`, `StickerSearchSheet.Configuration`, and `MessageChunk.Configuration` must be adapted rather than left as competing theme sources.
6. Theme scope is the built-in `ScreenChatContainer` composition and the library-owned child components it renders. Arbitrary host-provided views cannot be themed by introspection; host-provided sidebar row content remains responsible for its own internal fonts/colors unless it uses the library appearance values explicitly.
7. Do not theme geometry, layout, interaction behavior, data, persistence, or content. Fonts may specify font family/style, size, and weight; Colors may include `Color`, `ShapeStyle`/material, and border/fill styles where a component's actual rendered surface requires them.

## Protocol shape

```swift
public protocol ScreenChatThemeProviding {
    var colors: ScreenChatThemeColors { get }
    var fonts: ScreenChatThemeFonts { get }
}
```

`ScreenChatContainerTheme` will be the built-in concrete theme value conforming to this protocol. Its public theme payload consists of `colors` and `fonts`; preset identity and preview metadata remain separate from required visual values. `ScreenChatThemeColors` and `ScreenChatThemeFonts` contain required nested values with explicit initializers. Required fields should not have default arguments. A preset factory supplies complete valid values for System, Midnight, Ocean, Rose, and Forest.

The protocol exists to make incompleteness visible when authoring a theme. Components receive their own scoped appearance values or a narrowly scoped render configuration derived from the theme; they do not conform to the protocol.

## Required Colors inventory

The following is the required minimum inventory. Additional fields should only be added when the code audit confirms a real rendered component needs them.

### Container and theme picker

- Container shell background, content surface, separator, and modal/scrim color.
- Theme-picker button foreground, normal background, and pressed background.
- Theme-picker sheet background/surface, preset title and subtitle text, preset accent swatch, selected-state indicator, and primary action text where not supplied by a deliberate system semantic style.

### Sidebar and its SearchBar subcomponent

- Sidebar background.
- Header title, header icon, new-conversation icon foreground, and new-conversation button background.
- SearchBar outer background, text, placeholder, search icon, and border. This is one authoritative SearchBar color group nested under Sidebar; do not separately define duplicate colors in both Sidebar and SearchBar theme groups.
- Section heading text.
- Conversation row primary and secondary text, default background, selected foreground, selected background, and row separator if rendered by the library-owned row.
- Footer primary/secondary text, icon, and background.

### ScreenChat header and message content

- Screen background, header surface, separator.
- Header title, navigation/action icons, subtitle, online and offline status indicators.
- Day/date label foreground and surface if one is rendered.
- Avatar placeholder background and foreground for incoming and outgoing avatars.
- Incoming and outgoing message text.
- Incoming/outgoing message bubble fill, border, and timestamp color, including the `MessageChunk` / `MessageBubble` configuration values currently initialized with system defaults.

### InputContainer and InputBar

- Composer/input surface (including the fallback material treatment if the surface is configurable), typed text, placeholder, and utility icon foreground.
- Send and stop action button background and foreground.
- Emoji and plus utility-button circle background and foreground.
- The lens-shaped intersection color between the overlapping emoji and plus utility buttons; this is a required Colors token, not a blend inferred at render time.
- Floating send button shown over the sticker panel: background, icon/foreground, and border.
- InputActionPanel surface, tile surface, action icon foreground, and action title/secondary text.

### StickerKeyboard and nested EmojiPanel

- Keyboard panel background/material, top border, category divider, and category-bar background.
- Category icon foreground, selected category background, and selected category border.
- Sticker loading placeholder surface and sticker-load failure icon color.
- Empty-state icon, primary text, and secondary text.
- Emoji panel/grid surface and any selected-section surface that is distinct from the overall keyboard surface.
- The emoji glyphs themselves are Unicode glyphs; do not invent a text color token for glyphs that the system renders in their native color. Their font size belongs in Fonts.

### StickerSearchSheet

- Sheet/surface background where the implementation paints it directly.
- Title/primary text, secondary/metadata text, search input background, placeholder, and search/selection/action icons where currently styled by the component.
- Pack tile and state surfaces only where the component renders them directly; host-provided or remote pack artwork is not recolored.

## Required Fonts inventory

Fonts are grouped using the same component hierarchy. Include actual text typography and icon glyph sizing where a symbol is rendered with a font. Do not add empty font groups for components that render no text.

- Container/theme picker: preset title, preset subtitle, button/symbol sizing, selected indicator sizing, and navigation/action label typography.
- Sidebar: header title, header icon, new-conversation icon, section heading, and any library-owned primary/secondary row labels or footer labels. A generic caller-supplied `rowContent` cannot be styled internally by the container; document that boundary.
- Sidebar SearchBar: editable text and placeholder font; search icon font size.
- ScreenChat: header title, subtitle, day/date label, message body, message timestamp, and header action icon sizes.
- InputContainer/InputBar: text-entry font, utility icon font (including the enlarged 24-point emoji/plus symbols), send/stop icon fonts, and floating send-button icon font.
- InputActionPanel: action icon font and action title font.
- StickerKeyboard/EmojiPanel: emoji glyph font size, category icon font, and empty-state title/body fonts.
- StickerSearchSheet: sheet title, pack title, description/metadata, search field, action labels, and relevant icon font sizes.

## Integration and migration

- Audit every color/font literal in the actual ScreenChatContainer composition before coding, including `ScreenChatContainer.swift`, `ScreenChat.swift`, `ScreenChatConfig.swift`, `ScreenChatThemes.swift`, `HeaderChatScreen`, `ChatContentContainer`, `InputContainer`, `InputBar`, `InputActionPanel`, `StickerKeyboard`, `StickerSearchSheet`, `SidebarSettingsEntry`, `Sidebar`, `SearchBar`, and `MessageChunk`.
- Introduce the protocol and two required theme aggregates in the ScreenChatContainer theme module. Keep existing preset names and behavior; make each preset provide a complete Colors and Fonts value.
- Derive each existing component-specific appearance/configuration from the authoritative theme values at the composition boundary, or replace its duplicated theme-only fields with a scoped appearance type. Do not leave two independently configurable values for the same rendered property.
- Keep layout and behavior settings (for example keyboard height, columns, spacing, and button dimensions) outside the required Colors/Fonts contract unless a dimension is inherently a font-size token.
- Wire the sidebar's theme search colors into the actual shared `SearchBar` styles; currently `SidebarAppearance.Search` exists but `Sidebar` calls `SearchBar` without passing appearance styles.
- Replace theme-sensitive hard-coded system colors/fonts in the in-scope built-in components with the required values. Preserve intentional system materials or semantic system colors only when explicitly represented by the theme contract or deliberately documented as platform-owned.
- Keep the container's public API coherent: avoid increasing positional closure arguments for every new component. Prefer a typed theme/render context at the composition boundary and narrow component-specific appearance values inside it. Audit repository call sites before deciding whether a compatibility overload is needed.
- Do not alter unrelated app behavior, interaction state, layout, persistence, or data sources as part of this theme work.

## Verification and acceptance criteria

1. The protocol has exactly two top-level required sections: `colors` and `fonts`.
2. A conforming complete theme cannot omit any required nested Colors/Fonts field without a compile-time construction error.
3. The five existing presets each supply complete values and retain their intended appearance, including System light/dark behavior.
4. The actual SearchBar displayed inside Sidebar receives theme colors for its background, text, placeholder, icon, and border.
5. StickerKeyboard, the nested EmojiPanel, StickerSearchSheet, InputActionPanel, InputBar/InputContainer, MessageChunk, and ScreenChat header consume the corresponding theme values rather than unrelated hard-coded colors/fonts.
6. No duplicate authoritative source exists for the same visual property across `ScreenChatConfig`, legacy component configurations, and the new theme aggregates.
7. Existing component-only use remains usable with its documented standalone defaults; the container's complete theme does not depend on those defaults to fill required values.
8. Existing in-repository call sites compile; any unavoidable public API migration is minimized and documented.
9. Build the current iOS demo target and inspect the UI for all available presets; run `git diff --check` on changed files.
10. Preserve all pre-existing worktree changes. Do not reset, clean, stage, commit, or push unrelated work.

## Out of scope

- Styling arbitrary external `View` internals through environment magic or runtime introspection.
- Rewriting every reusable component in the repository to use this protocol.
- Adding geometry/layout tokens to the Colors/Fonts protocol.
- Changing interaction behavior, animations, data ownership, networking, or persistence.
