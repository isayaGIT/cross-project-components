# EmbeddedBrowser Component Design

## Status

Approved by the user on 2026-10-21; implementation and package build verification complete.

## Goal

Add a reusable, lightweight macOS embedded web browser to `Cross-Project-Components`, allowing a host view to display ordinary web links inside the app without launching Safari for every navigation. Keep it opt-in: existing links and host-app behavior do not change unless the host explicitly uses the component or routes a link to it.

## Chosen approach

Use Apple's `WKWebView` through SwiftUI's `NSViewRepresentable`. `WKWebView` uses WebKit, the same engine family used by Safari, but it is not the Safari application and does not automatically provide Safari's browser chrome or all of its features. The component owns only its own web view and optional minimal toolbar; the host app owns when and where the component is presented.

This is preferred over bundling Chromium because the goal is an in-app reader/browser panel, not a separate full-featured browser, and native WebKit avoids shipping another large browser runtime.

## Public API and responsibilities

Provide a public SwiftUI `EmbeddedBrowserView` with:

- An initial URL and an explicit way for the host to request navigation to a new URL after presentation.
- A small `EmbeddedBrowserConfiguration` value controlling visible toolbar elements and whether the address field is shown.
- Optional URL/loading callbacks and a navigation-failure callback so the host can reflect navigation state without reaching into `WKWebView` internals.
- A navigation policy callback for links or schemes the component should not silently handle.

The component should expose the common browsing actions only: back, forward, reload, load progress, and optionally a URL field. It should not implement bookmarks, browser tabs, extensions, history management, downloads UI, or a custom cookie manager in the first version.

## Navigation and safety behavior

- `http` and `https` links navigate inside the embedded web view by default.
- A link targeting a new window should be handled predictably inside the same view unless the host's policy chooses otherwise; it must not create an unmanaged blank web view.
- Non-web schemes (for example, `mailto:` or application-specific schemes) are surfaced to the host policy rather than automatically launched without host consent.
- Navigation failures should leave the browser usable and report state through the available callback; do not hide errors by silently claiming navigation succeeded.
- Use the standard persistent WebKit website data store by default so ordinary login sessions can persist in the app's WebKit data store. Do not promise that Safari cookies or Safari's login state are shared: WKWebView's website data is separate from Safari's.
- The component is a web view, not a security boundary or full browser sandbox policy. Hosts remain responsible for deciding which URLs they trust and how external schemes are handled.

## Repository fit

Follow the existing Swift Package and public SwiftUI component conventions. Keep implementation focused in `Components/EmbeddedBrowser/` and include a README or API usage section describing initialization, URL changes, navigation policy, and limitations. Do not add a test target solely for this component if the repository remains intentionally source-focused; validate with `swift build` and the host integration build where available.

## Integration boundary

The component must not globally intercept links, change `NSWorkspace` behavior, or modify any existing host application. A host view can explicitly present `EmbeddedBrowserView` in its own content area or panel and pass the selected URL. Integration into `Project-Knowledge-Navigator` is a separate host-side change and is not included in this component-library change unless explicitly requested later.

## Verification

- Build the Swift package on the repository's supported macOS target.
- Run `git diff --check` and inspect the public API for unnecessary abstractions.
- If host integration is later requested, verify ordinary HTTP(S) navigation, back/forward/reload, loading state, `target="_blank"`, unsupported schemes, and that unrelated links retain their existing behavior.
- Do not report manual GUI acceptance unless it has actually been exercised.

## Out of scope

Full Safari parity, Chromium bundling, browser extensions, tab management, bookmarks, download manager, private browsing UI, automatic global link interception, and changes to any host app.
