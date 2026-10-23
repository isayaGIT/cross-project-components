import SwiftUI

/// A standalone, native SwiftUI message composer with an optional accessory panel.
///
/// The caller supplies the panel view. InputBar only coordinates focus and panel
/// presentation; it does not know about or construct any specific keyboard type.
public struct InputBar: View {
    @Binding private var text: String
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isTextFieldFocused: Bool
    @State private var isStickerKeyboardPresented = false

    private let placeholder: String
    private let isGenerating: Bool
    private let accessoryPanel: AnyView?
    private let onSend: () -> Void
    private let onStop: (() -> Void)?
    private let onAttach: (() -> Void)?

    /// Creates a composer whose draft and generation state are controlled by its caller.
    ///
    /// - Parameters:
    ///   - text: The editable draft. The caller remains responsible for clearing it after a successful send.
    ///   - placeholder: Placeholder shown while the draft is empty.
    ///   - isGenerating: Shows a stop control instead of send when `true`.
    ///   - maxLines: Retained for source compatibility; the composer is intentionally single-line.
    ///   - accessoryPanel: Optional content shown when the accessory button is tapped. The supplied view owns its UI and behavior.
    ///   - onSend: Called for a non-empty draft when the user submits it.
    ///   - onStop: Called when generation is active and the stop control is tapped. The control is disabled when omitted.
    ///   - onAttach: Optional attachment action. Its control is hidden when omitted.
    ///   - onTools: Retained for source compatibility; the tools button is no longer displayed.
    public init(
        text: Binding<String>,
        placeholder: String = "Message",
        isGenerating: Bool = false,
        maxLines: Int = 1,
        accessoryPanel: AnyView? = nil,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil,
        onTools: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isGenerating = isGenerating
        _ = maxLines
        self.accessoryPanel = accessoryPanel
        self.onSend = onSend
        self.onStop = onStop
        self.onAttach = onAttach
        _ = onTools
    }

    private var canSend: Bool {
        !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            if isStickerKeyboardPresented, let accessoryPanel {
                accessoryPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            composer
        }
        .animation(.easeInOut(duration: 0.22), value: isStickerKeyboardPresented)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            accessoryButton(systemName: "plus", label: "Add attachment", action: { onAttach?() })
                .opacity(onAttach == nil ? 0.72 : 1)
                .disabled(onAttach == nil)

            TextField(placeholder, text: $text, axis: .horizontal)
                .font(.system(size: 16))
                .lineLimit(1...1)
                .submitLabel(.send)
                .focused($isTextFieldFocused)
                .onSubmit(submit)
                .accessibilityLabel(placeholder)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            if accessoryPanel != nil {
                accessoryButton(
                    systemName: isStickerKeyboardPresented ? "keyboard" : "face.smiling",
                    label: isStickerKeyboardPresented ? "Show system keyboard" : "Show sticker keyboard",
                    action: isStickerKeyboardPresented ? showSystemKeyboard : showStickerKeyboard
                )
            } else {
                accessoryButton(systemName: "face.smiling", label: "Emoji", action: {})
                    .disabled(true)
                    .opacity(0.72)
            }

            if isGenerating {
                Button { onStop?() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(actionForeground)
                        .frame(width: 34, height: 34)
                        .background(actionBackground, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(onStop == nil)
                .accessibilityLabel("Stop generating")
            } else if canSend {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(actionForeground)
                        .frame(width: 34, height: 34)
                        .background(actionBackground, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if #available(iOS 26.0, *) {
                Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
    }

    private var actionBackground: Color { Color.primary }
    private var actionForeground: Color { colorScheme == .dark ? .black : .white }

    private func accessoryButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
                .background {
                    if #available(iOS 26.0, *) {
                        Circle().fill(.clear).glassEffect(.regular, in: Circle())
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func showStickerKeyboard() {
        guard accessoryPanel != nil else { return }
        isTextFieldFocused = false
        withAnimation(.easeInOut(duration: 0.22)) {
            isStickerKeyboardPresented = true
        }
    }

    private func showSystemKeyboard() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isStickerKeyboardPresented = false
        }
        isTextFieldFocused = true
    }

    private func submit() {
        guard canSend else { return }
        isStickerKeyboardPresented = false
        onSend()
    }
}
