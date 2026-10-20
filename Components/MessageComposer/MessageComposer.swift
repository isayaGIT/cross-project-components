import SwiftUI

/// A reusable chat composer with attachment, voice, text-entry, and send actions.
/// The host app owns recording, calling, attachments, and message delivery.
public struct MessageComposer: View {
    @Binding private var text: String
    private let placeholder: String
    private let onSend: (String) -> Void
    private let onVoice: () -> Void
    private let onAddAttachment: () -> Void
    private let onCall: (() -> Void)?

    public var tint: Color
    public var fieldBackground: Color
    public var barBackground: Color
    public var showsCallButton: Bool
    public var maximumLines: Int

    public init(
        text: Binding<String>,
        placeholder: String = "Message…",
        tint: Color = .accentColor,
        fieldBackground: Color = Color.primary.opacity(0.06),
        barBackground: Color = .clear,
        showsCallButton: Bool = false,
        maximumLines: Int = 8,
        onSend: @escaping (String) -> Void,
        onVoice: @escaping () -> Void,
        onAddAttachment: @escaping () -> Void = {},
        onCall: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.tint = tint
        self.fieldBackground = fieldBackground
        self.barBackground = barBackground
        self.showsCallButton = showsCallButton
        self.maximumLines = max(1, maximumLines)
        self.onSend = onSend
        self.onVoice = onVoice
        self.onAddAttachment = onAddAttachment
        self.onCall = onCall
    }

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            actionButton("plus", label: "Add attachment", action: onAddAttachment)
            HStack(alignment: .bottom, spacing: 8) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...maximumLines)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 11)
                    .accessibilityLabel(placeholder)
                if hasText {
                    actionButton("arrow.up", label: "Send message", prominent: true) {
                        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !message.isEmpty else { return }
                        onSend(message)
                    }
                } else {
                    actionButton("mic.fill", label: "Record voice message", action: onVoice)
                    if showsCallButton, let onCall {
                        actionButton("phone.fill", label: "Start call", action: onCall)
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(barBackground)
    }

    private func actionButton(_ symbol: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : tint)
                .frame(width: 38, height: 38)
                .background(prominent ? tint : Color.clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var text = "Write something…"
        var body: some View {
            VStack {
                Spacer()
                MessageComposer(text: $text, showsCallButton: true, onSend: { _ in text = "" }, onVoice: {}, onAddAttachment: {}, onCall: {})
            }.frame(width: 420, height: 160).padding().background(Color(nsColor: .windowBackgroundColor))
        }
    }
    return PreviewHost()
}
