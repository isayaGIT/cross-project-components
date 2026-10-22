# TreeView Gesture Arbitration Implementation Plan

Date: 2026-10-21
Spec: `docs/superpowers/specs/2026-10-21-treeview-gesture-arbitration-design.md`
Repositories: `isayaGIT/cross-project-components`, `isayaGIT/Project-Knowledge-Navigator`

## Objective

Implement the approved design as a small, deterministic pointer arbitration mechanism with one winner per pointer sequence. Preserve AppKit-native selection, text editing, disclosure and drag/drop; keep the existing `gestureLayers:` initializer source-compatible and retain `interactiveHitTest` as a legacy fallback.

## Work sequence

1. **Establish the baseline**
   - Confirm both repositories' branches and worktree status; preserve the host repository's pre-existing untracked `docs/superpowers/`.
   - Inspect TreeView snapshot/projection resolution, cell hit-testing, outline mouse-down/double-click, hosted filmstrip view, and host tests.
   - Record current API usages and identify pointer paths that can trigger the same gesture twice.

2. **Add an explicit resolution contract**
   - Introduce minimal public route/resolution types alongside `TreeGestureLayer`, representing a claim and its delivery route.
   - Keep priority ordering deterministic; registration order breaks ties.
   - Preserve existing `claims(_:) -> Bool` conformers through a compatibility adapter/defaulted protocol evolution where Swift permits it; do not break existing source clients.
   - Keep `interactiveHitTest` as a lower-priority legacy fallback and document precedence without removing it.

3. **Centralize resolution**
   - Put priority sorting and claim resolution in one internal resolver shared by projection and event handling.
   - Return the winning layer/route, not just a boolean.
   - Keep hit testing location-only; never consult `NSApp.currentEvent`.
   - Ensure disclosure and native text-editor preflight cannot be captured by generic row layers.

4. **Retain sequence ownership**
   - Resolve the route at pointer-down using the concrete event's kind, click count and modifier flags.
   - Store the winner for the sequence and prevent lower-priority/native Tree callbacks from handling that same sequence.
   - Clear ownership on mouse-up, cancellation, window deactivation and controller teardown.
   - Prefer AppKit's native tracking/dispatch; do not add a separate polling loop. Do not re-resolve ownership as the pointer crosses row boundaries.

5. **Migrate host behavior**
   - Adapt the Knowledge Navigator filmstrip to the explicit route contract.
   - Move title double-click and relevant Tree-owned pointer decisions behind the same dispatcher only where doing so respects AppKit's actual event targeting.
   - Preserve keyboard command routing and native text-editor focus behavior.
   - Avoid changes to persistence, model mutation and drag/drop validation.

6. **Review and validate**
   - Run `swift build` in the shared component package.
   - Run the host app's existing macOS `xcodebuild test` scheme with signing disabled.
   - Check legacy initializer/layer source compatibility, `git diff --check`, public API docs and all changed call sites.
   - Add host-side tests only for deterministic resolver logic testable without fragile synthetic AppKit events; do not add a component-package test target solely for this.
   - Commit and push coherent component and host changes separately where validated.
   - Report automated results separately from manual interaction QA. Manual checks: normal row click, title double-click, disclosure, filmstrip click/drag/cross-boundary drag/double-click, native Tree drag/drop, text editing/selection, right-click/modifier-click, and cancellation/window switch.

## Constraints

- Keep resolver and lifecycle state narrowly scoped; no generic gesture DSL, registry, graph editor, or replacement drag engine.
- Once a layer claims a sequence, Tree selection, editing, disclosure or drag must not also process it.
- Keep pointer arbitration separate from keyboard shortcuts and context-menu command routing.
- Never claim manual AppKit checks passed unless actually exercised.
- Preserve unrelated user changes and pre-existing untracked files.

## Completion criteria

The resolver has one explicit result, each pointer sequence has one stable owner, ownership is reliably cleared, compatibility paths remain available, docs match behavior, builds/tests pass, diffs are clean, and manual QA limitations are stated precisely.
