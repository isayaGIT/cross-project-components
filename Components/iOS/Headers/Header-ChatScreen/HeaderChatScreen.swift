import SwiftUI

/// The complete navigation header for a chat screen.
/// The parent screen remains responsible for presenting the theme picker and chat settings.
public struct HeaderChatScreen: View {
    private let title: String
    private let onBack: (() -> Void)?
    private let onThemePicker: () -> Void
    private let onChatSettings: () -> Void
    private let configuration: ScreenChatConfig

    public init(
        title: String,
        configuration: ScreenChatConfig,
        onBack: (() -> Void)? = nil,
        onThemePicker: @escaping () -> Void,
        onChatSettings: @escaping () -> Void
    ) {
        self.title = title
        self.configuration = configuration
        self.onBack = onBack
        self.onThemePicker = onThemePicker
        self.onChatSettings = onChatSettings
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Equal-width side regions keep the title centered on the screen.
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(configuration.headerIconColor)
                            .frame(width: 36, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("展开聊天列表")
                } else {
                    Color.clear.frame(width: 36, height: 40)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Text(title)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                Button(action: onThemePicker) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(configuration.headerIconColor)
                        .frame(width: 36, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("聊天主题")
                .accessibilityHint("打开主题选择")

                Button(action: onChatSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(configuration.headerIconColor)
                        .frame(width: 36, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("聊天设置")
                .accessibilityHint("打开聊天设置")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(configuration.titleColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Rectangle()
                .fill(configuration.headerBackground)
                .ignoresSafeArea(edges: .top)
        }
    }
}
