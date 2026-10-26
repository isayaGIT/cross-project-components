import SwiftUI

/// Apps exposed from the chat header. Navigation and app behavior stay with the host.
public enum ScreenChatApp: String, CaseIterable, Identifiable {
    case diary
    case music
    case mailbox
    case companionChannel

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .diary: return "一起记日记"
        case .music: return "一起听"
        case .mailbox: return "信箱"
        case .companionChannel: return "陪伴频道"
        }
    }

    public var subtitle: String {
        switch self {
        case .diary: return "记录共同经历，按日期回顾"
        case .music: return "一起听歌与分享音乐"
        case .mailbox: return "收取和查看角色来信"
        case .companionChannel: return "进入独立的陪伴对话"
        }
    }

    public var symbol: String {
        switch self {
        case .diary: return "book.closed.fill"
        case .music: return "headphones"
        case .mailbox: return "envelope.fill"
        case .companionChannel: return "bubble.left.and.bubble.right.fill"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .diary: return .orange
        case .music: return .pink
        case .mailbox: return .blue
        case .companionChannel: return .purple
        }
    }
}

/// A presentation-only app launcher. The host decides what selecting an app does.
public struct SheetApps: View {
    private let onSelect: (ScreenChatApp) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onSelect: @escaping (ScreenChatApp) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(ScreenChatApp.allCases) { app in
                        Button {
                            onSelect(app)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(app.tint.opacity(0.14))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Image(systemName: app.symbol)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(app.tint)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(app.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(16)
            }
            .navigationTitle("应用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview("应用") {
    SheetApps(onSelect: { _ in })
}
