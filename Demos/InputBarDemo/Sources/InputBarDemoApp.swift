import SwiftUI
import CrossProjectComponentsIOS
import StickerData

@main
struct InputBarDemoApp: App {
    var body: some Scene {
        WindowGroup { InputBarDemoView() }
    }
}

private struct InputBarDemoView: View {
    @State private var draft = ""
    @State private var isGenerating = false
    @State private var messages: [String] = [
        "This is a standalone demo for the native SwiftUI InputBar.",
        "Try typing a longer message to check multiline growth and keyboard behavior."
    ]
    @State private var activeAlert: DemoAlert?
    @State private var isStickerPreviewPresented = false
    @State private var isStickerSearchPresented = false
    @State private var lastStickerSearch = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                Text(message)
                                    .font(.body)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(index.isMultiple(of: 2) ? Color.secondary.opacity(0.12) : Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                Spacer(minLength: 36)
                            }
                            .id(index)
                        }
                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Generating… tap stop to end the demo state")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    InputBar(
                        text: $draft,
                        placeholder: "Message",
                        isGenerating: isGenerating,
                        maxLines: 6,
                        onSend: send,
                        onStop: { isGenerating = false },
                        onAttach: { activeAlert = .attachment },
                        onTools: { activeAlert = .tools }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(.bar)
                }
                .onChange(of: messages.count) { _, count in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
            .navigationTitle("InputBar Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sticker UI") { isStickerPreviewPresented = true }
                        .accessibilityLabel("Preview image sticker keyboard")
                }
            }
            .alert(item: $activeAlert) { alert in
                let message = alert == .stickerSearch
                    ? "Search request: \(lastStickerSearch)\nThe app-wide catalogue service is not connected in this demo."
                    : alert.message
                return Alert(title: Text(alert.title), message: Text(message), dismissButton: .default(Text("OK")))
            }
        }
        .overlay {
            ZStack {
                SheetCustom(
                    isPresented: $isStickerPreviewPresented,
                    configuration: .init(height: .points(390), background: Color(uiColor: .systemBackground))
                ) {
                    StickerKeyboardPreview(
                        onSelect: { sticker in
                            draft += " [\(sticker.name ?? sticker.id)] "
                            isStickerPreviewPresented = false
                        },
                        onSearchRequested: { isStickerSearchPresented = true }
                    )
                }
                .zIndex(1)

                StickerSearchSheet(isPresented: $isStickerSearchPresented) { query in
                    lastStickerSearch = query
                    activeAlert = .stickerSearch
                }
                .zIndex(2)
            }
        }
    }

    private func send() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isGenerating else { return }
        messages.append(message)
        draft = ""
    }
}

private enum DemoAlert: String, Identifiable {
    case attachment
    case tools
    case stickerSearch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .attachment: "Attachment action"
        case .tools: "Tools action"
        case .stickerSearch: "Sticker search"
        }
    }
    var message: String {
        switch self {
        case .attachment: "The optional attachment callback is connected."
        case .tools: "The optional tools callback is connected."
        case .stickerSearch: "The app-wide catalogue service is not connected in this demo."
        }
    }
}


private struct StickerKeyboardPreview: View {
    let onSelect: (Sticker) -> Void
    let onSearchRequested: () -> Void

    private let packs = [
        StickerPack(id: "demo-default", name: "Daily", coverAssetID: "sun", stickerIDs: ["sun-sticker", "cloud-sticker", "leaf-sticker", "flower-sticker"]),
        StickerPack(id: "demo-nature", name: "Nature", coverAssetID: "leaf", stickerIDs: ["leaf-sticker", "flower-sticker"])
    ]
    private let stickers = [
        Sticker(id: "sun-sticker", packID: "demo-default", assetID: "sun", name: "Sunny", tags: ["sun", "happy", "weather"]),
        Sticker(id: "cloud-sticker", packID: "demo-default", assetID: "cloud", name: "Cloud", tags: ["cloud", "weather"]),
        Sticker(id: "leaf-sticker", packID: "demo-nature", assetID: "leaf", name: "Leaf", tags: ["nature", "green"]),
        Sticker(id: "flower-sticker", packID: "demo-nature", assetID: "flower", name: "Flower", tags: ["nature", "flower"])
    ]
    private let assets = [
        StickerAsset(id: "sun", originalLocation: URL(string: "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=256&q=80") ?? URL(fileURLWithPath: "/dev/null")),
        StickerAsset(id: "cloud", originalLocation: URL(string: "https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=256&q=80" )!),
        StickerAsset(id: "leaf", originalLocation: URL(string: "https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=256&q=80")!),
        StickerAsset(id: "flower", originalLocation: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=256&q=80")!)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Sticker Keyboard").font(.headline).padding(.horizontal, 16).padding(.top, 16)
            Text("Live component preview · tap a sticker to insert it into the draft").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
            StickerKeyboard(
                stickers: stickers,
                packs: packs,
                assets: assets,
                userConfiguration: UserStickerConfiguration(selectedPackIDs: ["demo-nature"], favoriteStickerIDs: ["flower-sticker"]),
                defaultPackID: "demo-default",
                onSearch: { _ in },
                onSearchRequested: onSearchRequested,
                onSelect: onSelect
            )
        }
        .background(.regularMaterial)
    }
}
