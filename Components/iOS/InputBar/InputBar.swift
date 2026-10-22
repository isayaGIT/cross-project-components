import SwiftUI

/// A standalone, native SwiftUI message composer.
///
/// The caller owns the draft and generation state. This view only presents the
/// current state and reports user actions; it does not send requests or mutate
/// the draft on the caller's behalf.
public struct InputBar: View {
    @Binding private var text: String
    @Environment(\.colorScheme) private var colorScheme

    private let placeholder: String
    private let isGenerating: Bool
    private let maxLines: Int
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
    ///   - onSend: Called for a non-empty draft when the user submits it.
    ///   - onStop: Called when generation is active and the stop control is tapped. The control is disabled when omitted.
    ///   - onAttach: Optional attachment action. Its control is hidden when omitted.
    ///   - onTools: Optional tools/action-menu entry point. Its control is hidden when omitted.
    public init(
        text: Binding<String>,
        placeholder: String = "Message",
        isGenerating: Bool = false,
        maxLines: Int = 6,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil,
        onTools: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isGenerating = isGenerating
        self.maxLines = max(1, maxLines)
        self.onSend = onSend
        self.onStop = onStop
        self.onAttach = onAttach
        self.onTools = onTools
    }

    private var canSend: Bool {
        !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...maxLines)
                .submitLabel(.send)
                .onSubmit(submit)
                .accessibilityLabel(placeholder)
                .padding(.horizontal, 4)
                .padding(.top, 3)

            HStack(spacing: 10) {
                if let onAttach {
                    accessoryButton(
                        systemName: "plus",
                        label: "Add attachment",
                        action: onAttach
                    )
                }

                if let onTools {
                    accessoryButton(
                        systemName: "slider.horizontal.3",
                        label: "Tools",
                        action: onTools
                    )
                }

                Spacer(minLength: 8)

                if isGenerating {
                    Button {
                        onStop?()
                    } label: {
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
                } else {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(actionForeground)
                            .frame(width: 36, height: 36)
                            .background(canSend ? actionBackground : disabledActionBackground, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
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
    private var disabledActionBackground: Color { Color.primary.opacity(0.16) }

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

    private func submit() {
        guard canSend else { return }
        onSend()
    }
}
