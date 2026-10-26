import SwiftUI

/// A reusable Settings row for hosts that compose their own conversation sidebar.
public struct SidebarSettingsEntry: View {
    private let title: String
    private let symbol: String
    private let onSelect: () -> Void
    private let appearance: SidebarAppearance.Footer

    public init(
        title: String = "设置",
        symbol: String = "gearshape.fill",
        appearance: SidebarAppearance.Footer = .default,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.onSelect = onSelect
        self.appearance = appearance
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(appearance.icon)
                    .frame(width: 30)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.secondaryForeground)
            }
            .foregroundStyle(appearance.foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(appearance.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开模型服务与 API 凭据设置")
    }
}

#Preview("侧边栏设置入口") {
    SidebarSettingsEntry(onSelect: {})
        .padding()
}
