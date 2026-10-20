import AppKit
import SwiftUI
import WebKit

/// Controls which browser controls are visible in `EmbeddedBrowserView`.
public struct EmbeddedBrowserConfiguration {
    public var showsNavigationControls: Bool
    public var showsAddressField: Bool

    public init(
        showsNavigationControls: Bool = true,
        showsAddressField: Bool = false
    ) {
        self.showsNavigationControls = showsNavigationControls
        self.showsAddressField = showsAddressField
    }
}

/// The host's decision for a requested navigation.
public enum EmbeddedBrowserNavigationDecision {
    /// Permit the requested URL to load in the embedded web view.
    case allow
    /// Cancel the requested navigation.
    case cancel
}

/// A lightweight, reusable macOS web browser backed by Apple's WebKit.
///
/// Bind `url` to control navigation from the host. HTTP(S) links are loaded in
/// this view by default; non-web schemes are cancelled unless the host's
/// `onNavigationRequest` explicitly allows them.
public struct EmbeddedBrowserView: View {
    @Binding private var url: URL
    private let configuration: EmbeddedBrowserConfiguration
    private let onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)?
    private let onURLChange: ((URL) -> Void)?
    private let onLoadingChange: ((Bool) -> Void)?
    private let onNavigationFailure: ((Error) -> Void)?

    @StateObject private var browserState = EmbeddedBrowserState()
    @State private var addressText = ""

    public init(
        url: Binding<URL>,
        configuration: EmbeddedBrowserConfiguration = .init(),
        onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)? = nil,
        onURLChange: ((URL) -> Void)? = nil,
        onLoadingChange: ((Bool) -> Void)? = nil,
        onNavigationFailure: ((Error) -> Void)? = nil
    ) {
        self._url = url
        self.configuration = configuration
        self.onNavigationRequest = onNavigationRequest
        self.onURLChange = onURLChange
        self.onLoadingChange = onLoadingChange
        self.onNavigationFailure = onNavigationFailure
        self._addressText = State(initialValue: url.wrappedValue.absoluteString)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if configuration.showsNavigationControls || configuration.showsAddressField {
                HStack(spacing: 8) {
                    if configuration.showsNavigationControls {
                        Button { browserState.webView?.goBack() } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!browserState.canGoBack)
                        .help("Back")
                        .accessibilityLabel("Back")

                        Button { browserState.webView?.goForward() } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!browserState.canGoForward)
                        .help("Forward")
                        .accessibilityLabel("Forward")

                        Button { browserState.webView?.reload() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Reload")
                        .accessibilityLabel("Reload")
                    }

                    if configuration.showsAddressField {
                        TextField("Website address", text: $addressText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(loadAddress)
                            .accessibilityLabel("Website address")
                    }
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if browserState.isLoading {
                    ProgressView(value: browserState.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                }
            }

            EmbeddedBrowserWebView(
                url: $url,
                state: browserState,
                onNavigationRequest: onNavigationRequest,
                onURLChange: { newURL in
                    addressText = newURL.absoluteString
                    onURLChange?(newURL)
                },
                onLoadingChange: onLoadingChange,
                onNavigationFailure: onNavigationFailure
            )
        }
        .onChange(of: url) { newURL in
            addressText = newURL.absoluteString
        }
    }

    private func loadAddress() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let candidate: String
        if URLComponents(string: trimmed)?.scheme == nil {
            candidate = "https://\(trimmed)"
        } else {
            candidate = trimmed
        }

        guard let newURL = URL(string: candidate),
              let scheme = newURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }
        url = newURL
    }
}

@MainActor
private final class EmbeddedBrowserState: ObservableObject {
    weak var webView: WKWebView?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress = 0.0
}

private struct EmbeddedBrowserWebView: NSViewRepresentable {
    @Binding var url: URL
    let state: EmbeddedBrowserState
    let onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)?
    let onURLChange: ((URL) -> Void)?
    let onLoadingChange: ((Bool) -> Void)?
    let onNavigationFailure: ((Error) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            url: $url,
            state: state,
            onNavigationRequest: onNavigationRequest,
            onURLChange: onURLChange,
            onLoadingChange: onLoadingChange,
            onNavigationFailure: onNavigationFailure
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.attach(webView)
        state.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            url: $url,
            onNavigationRequest: onNavigationRequest,
            onURLChange: onURLChange,
            onLoadingChange: onLoadingChange,
            onNavigationFailure: onNavigationFailure
        )
        state.webView = webView

        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var url: Binding<URL>
        private let state: EmbeddedBrowserState
        private var onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)?
        private var onURLChange: ((URL) -> Void)?
        private var onLoadingChange: ((Bool) -> Void)?
        private var onNavigationFailure: ((Error) -> Void)?
        private var progressObservation: NSKeyValueObservation?

        init(
            url: Binding<URL>,
            state: EmbeddedBrowserState,
            onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)?,
            onURLChange: ((URL) -> Void)?,
            onLoadingChange: ((Bool) -> Void)?,
            onNavigationFailure: ((Error) -> Void)?
        ) {
            self.url = url
            self.state = state
            self.onNavigationRequest = onNavigationRequest
            self.onURLChange = onURLChange
            self.onLoadingChange = onLoadingChange
            self.onNavigationFailure = onNavigationFailure
        }

        func update(
            url: Binding<URL>,
            onNavigationRequest: ((URL) -> EmbeddedBrowserNavigationDecision)?,
            onURLChange: ((URL) -> Void)?,
            onLoadingChange: ((Bool) -> Void)?,
            onNavigationFailure: ((Error) -> Void)?
        ) {
            self.url = url
            self.onNavigationRequest = onNavigationRequest
            self.onURLChange = onURLChange
            self.onLoadingChange = onLoadingChange
            self.onNavigationFailure = onNavigationFailure
        }

        func attach(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.state.progress = webView.estimatedProgress
                    self?.refreshNavigationState(webView)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let requestedURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = requestedURL.scheme?.lowercased()
            let isWebURL = scheme == "http" || scheme == "https"
            let decision = onNavigationRequest?(requestedURL) ?? (isWebURL ? .allow : .cancel)
            decisionHandler(decision == .allow ? .allow : .cancel)
        }

        // WKWebView otherwise creates a separate view for target="_blank".
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            // The navigation policy delegate has already approved or rejected
            // this request; load it in the existing view without re-running policy.
            webView.load(navigationAction.request)
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
            onLoadingChange?(true)
            refreshNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            syncURL(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.progress = 1
            onLoadingChange?(false)
            syncURL(webView)
            refreshNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishLoading(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishLoading(webView, error: error)
        }

        private func finishLoading(_ webView: WKWebView, error: Error) {
            onNavigationFailure?(error)
            state.isLoading = false
            onLoadingChange?(false)
            syncURL(webView)
            refreshNavigationState(webView)
        }

        private func syncURL(_ webView: WKWebView) {
            guard let currentURL = webView.url else { return }
            if url.wrappedValue != currentURL {
                url.wrappedValue = currentURL
            }
            onURLChange?(currentURL)
        }

        private func refreshNavigationState(_ webView: WKWebView) {
            state.canGoBack = webView.canGoBack
            state.canGoForward = webView.canGoForward
        }
    }
}
