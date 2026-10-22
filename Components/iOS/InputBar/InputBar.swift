import SwiftUI

/// A standalone, native SwiftUI message composer with an optional emoji picker.
///
/// The caller owns the draft and generation state. InputBar coordinates focus and
/// panel presentation, while StickerKeyboard owns only its own emoji-picker UI.
public struct InputBar: View {
    @Binding private var text: String
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isTextFieldFocused: Bool
    @State private var isStickerKeyboardPresented = false

    private let placeholder: String
    private let isGenerating: Bool
    private let maxLines: Int
    private let stickerKeyboardConfiguration: StickerKeyboard.Configuration
    private let onSend: () -> Void
    private let onStop: (() -> Void)?
    private let onAttach: (() -> Void)?
    private let onTools: (() -> Void)?

    /// Creates a composer whose draft and generation state are controlled by its caller.
    ///
    /// - Parameters:
    ///   - text: The editable draft. The caller remains responsible for clearing it after a successful send.
    ///   - placeholder: Placeholder shown while the draft is empty.
    ///   - isGenerating: Shows a stop control instead of send when `true`.
    ///   - maxLines: Maximum number of visible text lines before the field scrolls.
    ///   - stickerKeyboardConfiguration: Public sizing and grid configuration for the emoji panel.
    ///   - onSend: Called for a non-empty draft when the user submits it.
    ///   - onStop: Called when generation is active and the stop control is tapped. The control is disabled when omitted.
    ///   - onAttach: Optional attachment action. Its control is hidden when omitted.
    ///   - onTools: Optional tools/action-menu entry point. Its control is hidden when omitted.
    public init(
        text: Binding<String>,
        placeholder: String = "Message",
        isGenerating: Bool = false,
        maxLines: Int = 6,
        stickerKeyboardConfiguration: StickerKeyboard.Configuration = .standard,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil,
        onTools: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isGenerating = isGenerating
        self.maxLines = max(1, maxLines)
        self.stickerKeyboardConfiguration = stickerKeyboardConfiguration
        self.onSend = onSend
        self.onStop = onStop
        self.onAttach = onAttach
        self.onTools = onTools
    }

    private var canSend: Bool {
        !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            composer
            if isStickerKeyboardPresented {
                StickerKeyboard(configuration: stickerKeyboardConfiguration) { emoji in
                    // SwiftUI's iOS 17 TextField API doesn't expose the insertion
                    // selection, so the component appends to the controlled draft.
                    text.append(emoji)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.22), value: isStickerKeyboardPresented)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...maxLines)
                .submitLabel(.send)
                .focused($isTextFieldFocused)
                .onSubmit(submit)
                .accessibilityLabel(placeholder)
                .padding(.horizontal, 4)
                .padding(.top, 3)

            HStack(spacing: 10) {
                if let onAttach {
                    accessoryButton(systemName: "plus", label: "Add attachment", action: onAttach)
                }
                if let onTools {
                    accessoryButton(systemName: "slider.horizontal.3", label: "Tools", action: onTools)
                }

                Spacer(minLength: 8)

                if isGenerating {
                    Button { onStop?() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(actionForeground)
                            .frame(width: 36, height: 36)
                            .background(actionBackground, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onStop == nil)
                    .accessibilityLabel("Stop generating")
                } else if isStickerKeyboardPresented {
                    accessoryButton(
                        systemName: "keyboard",
                        label: "Show system keyboard",
                        action: showSystemKeyboard
                    )
                } else if canSend {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(actionForeground)
                            .frame(width: 36, height: 36)
                            .background(actionBackground, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send message")
                } else {
                    accessoryButton(
                        systemName: "face.smiling",
                        label: "Show emoji keyboard",
                        action: showStickerKeyboard
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.05), radius: 12, y: 3)
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
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.055), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func showStickerKeyboard() {
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
