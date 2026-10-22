import SwiftUI
import CrossProjectComponentsIOS

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
            .alert(item: $activeAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
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
    var id: String { rawValue }
    var title: String {
        switch self {
        case .attachment: "Attachment action"
        case .tools: "Tools action"
        }
    }
    var message: String {
        switch self {
        case .attachment: "The optional attachment callback is connected."
        case .tools: "The optional tools callback is connected."
        }
    }
}
