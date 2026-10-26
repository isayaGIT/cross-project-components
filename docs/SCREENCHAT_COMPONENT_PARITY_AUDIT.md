# ScreenChat Demo ↔ Reusable Component Parity Audit

Date: 2026-10-25  
Scope: `Demos/ScreenChatDemo/Sources/ScreenChatDemoApp.swift` compared with `Components/iOS/ScreenChatContainer/**`.  
Method: static source tracing, public-API review, test inventory review, and iOS Simulator build. This is an architectural/behavioral audit; no visual runtime comparison was performed.

## Executive summary

The Demo is already composed from `ScreenChatContainer` and `ScreenChat`, but the composition still contains several distinct responsibility layers. The calendar/diary designer and provider-settings overlay are host-owned features and are not, by themselves, component leaks. The higher-risk issues are inside the reusable `ScreenChat` contract: message sending is internally stateful without a host event callback, sticker search is wired to a no-op callback, and selecting Music dispatches two different host callbacks for one action. The component area also has no dedicated tests for `ScreenChatContainer`, `ScreenChat`, or `InputContainer`, so current build success does not establish interaction parity.

## Ownership map

| Feature / behavior | Current owner | Assessment |
|---|---|---|
| Sidebar open/close, coordinated theme, theme picker, hosted sheet presentation, shared input focus/sticker-panel state | `ScreenChatContainer` | Correct component-level ownership. Public content builder receives `ScreenChatConfig` and `ScreenChatContainerInputContext`. |
| Chat header, message list layout, composer, local message list, profile-card presentation, Apps sheet, sticker-search presentation | `ScreenChat` | Mostly component-owned, but several integration points are incomplete (see findings). |
| Composer panel toggles, text field focus, accessory panel switching, local fallback sticker state | `InputContainer` | Correctly encapsulated. It supports both a container-provided context and a local fallback. Needs interaction tests for both modes. |
| Conversation samples/selection, sidebar row content, profile demo data, alert placeholders for host actions | `ScreenChatDemoApp` | Appropriate Demo/App responsibility. |
| Diary overlay, calendar month transition, calendar artwork, grid styling, photo picker, calendar theme designer | `ScreenChatDemoApp` | Appropriate if the calendar is a Demo-only app feature. If the diary/calendar is intended to be a reusable product component, it is currently outside the reusable ScreenChat component boundary and must be audited separately. |
| API-provider settings overlay and fake provider actions | `ScreenChatDemoApp` | Appropriate host-owned settings flow; the app supplies provider data and actions. Its placement as a root overlay is not automatically a defect. |

## Findings

### P1 — ScreenChat does not expose a host message-send event

Evidence: `ScreenChat.swift:133-180` passes `onSend: sendMessage` to `InputContainer`; `ScreenChat.swift:362-375` appends a new `ScreenChatMessage` to private `@State messages` and clears the draft. The public initializer accepts an initial `messages` array but has no `onSendMessage` callback or binding for the host to own subsequent messages (`ScreenChat.swift:35-73`).

Impact: a host can provide an initial transcript and configure stop-generation, but cannot observe a sent message through the public ScreenChat API. The local echo works in a demo; a real app must either duplicate input handling elsewhere or fork/replace this component behavior. This is a concrete reuse/API boundary gap, not a Demo-only concern.

Recommended remediation: define the intended state contract explicitly. Prefer a host callback such as `onSendMessage` for the submitted text/message and document whether ScreenChat performs optimistic local echo. For a host-owned transcript, expose a binding or a clear external message-update path. Add tests that verify callback invocation, whitespace rejection, draft clearing, and no duplicate messages. Avoid silently changing the current preview/demo behavior.

### P1 — Sticker search is visually integrated but functionally disconnected

Evidence: `ScreenChat.swift:141-149` configures `StickerKeyboard` with empty `stickers`, `packs`, and `assets`, and an empty `onSelect`; `ScreenChat.swift:252-264` constructs `StickerSearchSheet` with `onSearch: { _ in }`.

Impact: the UI can open the search surface, but the search action has no route to host-provided catalogue/search behavior. The empty catalogue may be intentional demo data, but the no-op callback is an explicit missing integration seam. A copied component can reproduce the sheet appearance without reproducing a useful search flow.

Recommended remediation: expose the required sticker catalogue and search/selection callbacks as `ScreenChat` inputs, or inject a cohesive sticker feature configuration/provider. Keep network access, persistence, and install/like policy host-owned. Add a test that verifies a submitted search query reaches the host callback and selection events are forwarded.

### P2 — Music action dispatches two host callbacks for one tap

Evidence: `ScreenChat.swift:160-163` calls both `onOpenApp?(.music)` and `onInputAction?(.music)` from the same action tile.

Impact: a host that implements both callback families can navigate/open Music and also execute the attachment action. The Demo's alert placeholder makes this less visible, but a real integration can observe duplicate side effects. The public contract does not explain why Music is exceptional.

Recommended remediation: choose one canonical action route for Music or define and document a deliberate two-event contract with distinct semantics. Default recommendation: route Music through `onOpenApp` only if it is an app launcher, otherwise through `onInputAction` only. Add a callback-count test.

### P2 — No parity-focused tests cover the ScreenChat component boundary

Evidence: `Tests/CrossProjectComponentsIOSTests` currently contains tests for StickerKeyboard, MessageBubbleShape, MomentSingleMoment, and VoiceMessage, but no `ScreenChatContainer`, `ScreenChat`, or `InputContainer` test files.

Impact: the most important contract in this audit—whether a fresh host can reproduce behavior using only public APIs—is not protected by automated regression tests. The app can compile while behavior is missing or duplicated.

Recommended remediation: add a dedicated parity test suite, starting with the three findings above, then cover hosted vs standalone sheet presentation, keyboard/sticker panel mutual exclusion, reduce-motion sidebar transitions, and theme changes. Where SwiftUI interaction behavior cannot be robustly asserted in unit tests, add an explicit demo host/UITest scenario.

### P3 — Demo-only calendar implementation is a separate componentization decision

Evidence: `ScreenChatDemoApp.swift:10-18`, `70-158`, `182-235`, `293-313`, and `321-442` own diary presentation state, calendar month transitions, visual configuration, image selection, and the theme designer.

Impact: this does not invalidate ScreenChatContainer reuse because the calendar is a separate host feature. However, if the intended acceptance criterion is to reproduce the complete Demo—including the diary flow—by assembling reusable components, that feature currently depends on private Demo-only view code and cannot be recreated by copying ScreenChatContainer alone.

Recommended remediation: keep it in the Demo if it is only a showcase. If diary/calendar is part of the reusable product surface, create a separate calendar component/API and audit it independently; do not inflate ScreenChatContainer with unrelated calendar responsibilities.

## What is not a defect by itself

- Demo-specific conversations, mock profile content, and alert placeholders are normal host responsibilities.
- The calendar theme designer and API-key/provider settings are not required to be inside ScreenChatContainer unless the product explicitly defines them as reusable components.
- `ScreenChatContainer` intentionally asks custom sidebar views to apply the supplied `SidebarAppearance`; generic SwiftUI containers cannot recolor arbitrary child content automatically. This constraint is documented in its README.
- `ScreenChat` supports both a container-hosted presentation path and a standalone fallback path. This is a valid flexibility choice, but both paths need behavior tests.

## Verification results

- **Passed:** `xcodebuild -project Demos/ScreenChatDemo/ScreenChatDemo.xcodeproj -scheme ScreenChatDemo -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ScreenChatParityAuditDerivedData build CODE_SIGNING_ALLOWED=NO` (exit code 0).
- **Not a valid verification path:** root `swift test` attempted a macOS build of the iOS target and failed with `no such module 'UIKit'`; it also emitted many invalid-exclude/unhandled-file warnings. This is a platform/target mismatch and package hygiene signal, not evidence that the iOS Demo fails to build.
- **Coverage gap confirmed:** no current tests mention `ScreenChatContainer`, `ScreenChat`, or `InputContainer`.
- **Not performed:** simulator launch, visual screenshot comparison, keyboard/gesture interaction tests, VoiceOver checks, or a clean-room second-host sample. Build success alone does not establish behavioral or visual parity.

## Recommended implementation order

1. Clarify and fix the `ScreenChat` message ownership/send callback contract.
2. Replace the no-op sticker-search/selection seam with explicit host-injectable behavior (preserving a useful empty-state default).
3. Make Music dispatch exactly one documented host action.
4. Add parity tests around the public API and hosted/standalone presentation paths.
5. Add a minimal second-host sample that composes the same components without Demo-private helpers; use it as the replication acceptance test.
6. Decide separately whether the diary/calendar needs its own reusable component.

## Acceptance criteria for future parity work

- A fresh host can compose the screen using only documented public APIs and its own business data/actions.
- No essential UI behavior depends on a private Demo view, private state mutation, or a parent overlay that the component API does not document.
- Each user action invokes its intended host callback exactly once.
- Host-owned state (messages, search/catalogue results, navigation, persistence) has an explicit input/output contract.
- Tests cover both the standalone and container-integrated modes, and the iOS Simulator build remains green.
