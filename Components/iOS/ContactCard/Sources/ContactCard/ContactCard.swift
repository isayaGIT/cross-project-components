import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A native character profile for AI companion apps. The caller owns navigation, images,
/// relationship state, and persistence; this view only presents the supplied profile.
public struct ContactCard: View {
    public struct Stat: Identifiable, Hashable, Sendable {
        public let id: String
        public var value: String
        public var label: String

        public init(id: String = UUID().uuidString, value: String, label: String) {
            self.id = id
            self.value = value
            self.label = label
        }
    }

    /// Profile content. The avatar and optional cover are already-resolved SwiftUI images;
    /// networking and caching remain the host application's responsibility.
    public struct Profile {
        public var name: String
        public var subtitle: String?
        public var bio: String?
        public var avatar: Image?
        public var cover: Image?
        public var isOnline: Bool
        public var relationshipLabel: String?
        public var tags: [String]
        public var stats: [Stat]

        public init(
            name: String,
            subtitle: String? = nil,
            bio: String? = nil,
            avatar: Image? = nil,
            cover: Image? = nil,
            isOnline: Bool = false,
            relationshipLabel: String? = nil,
            tags: [String] = [],
            stats: [Stat] = []
        ) {
            self.name = name
            self.subtitle = subtitle
            self.bio = bio
            self.avatar = avatar
            self.cover = cover
            self.isOnline = isOnline
            self.relationshipLabel = relationshipLabel
            self.tags = tags
            self.stats = stats
        }
    }

    /// Tunable visual language. Defaults use adaptive system colors and a restrained accent.
    public struct Style {
        public var accent: Color
        public var surface: Color
        public var secondarySurface: Color
        public var primaryText: Color
        public var secondaryText: Color
        public var border: Color
        public var cornerRadius: CGFloat
        public var horizontalPadding: CGFloat

        public init(
            accent: Color = .pink,
            surface: Color? = nil,
            secondarySurface: Color? = nil,
            primaryText: Color = .primary,
            secondaryText: Color = .secondary,
            border: Color = Color.primary.opacity(0.08),
            cornerRadius: CGFloat = 30,
            horizontalPadding: CGFloat = 22
        ) {
            self.accent = accent
            self.surface = surface ?? Self.platformSurface
            self.secondarySurface = secondarySurface ?? Self.platformSecondarySurface
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.border = border
            self.cornerRadius = max(12, cornerRadius)
            self.horizontalPadding = max(12, horizontalPadding)
        }

        public static let companion = Style()

        private static var platformSurface: Color {
            #if canImport(UIKit)
            return Color(uiColor: .secondarySystemBackground)
            #else
            return Color(nsColor: .windowBackgroundColor)
            #endif
        }

        private static var platformSecondarySurface: Color {
            #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemBackground)
            #else
            return Color(nsColor: .underPageBackgroundColor)
            #endif
        }
    }

    private let profile: Profile
    private let style: Style
    private let primaryActionTitle: String
    private let secondaryActionTitle: String?
    private let onPrimaryAction: (() -> Void)?
    private let onSecondaryAction: (() -> Void)?
    private let onClose: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(
        profile: Profile,
        style: Style = .companion,
        primaryActionTitle: String = "开始聊天",
        secondaryActionTitle: String? = "查看朋友圈",
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.style = style
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                profileDetails
                actionButtons
            }
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background(style.surface, in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(style.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 28, x: 0, y: 12)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86), value: appeared)
        }
        .background(Color.clear)
        .onAppear { appeared = true }
        .accessibilityElement(children: .contain)
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            Group {
                if let cover = profile.cover {
                    cover.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [style.accent.opacity(0.42), style.accent.opacity(0.10), style.secondarySurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: 190)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, style.surface.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            }

            HStack {
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(style.primaryText)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭名片")
                .opacity(onClose == nil ? 0 : 1)
                .disabled(onClose == nil)
                Spacer()
                if profile.isOnline {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("在线")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(style.primaryText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityLabel("当前在线")
                }
            }
            .padding(16)

            avatar
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: 52)
        }
        .frame(height: 220)
        .padding(.bottom, 52)
    }

    private var avatar: some View {
        Group {
            if let avatar = profile.avatar {
                avatar.resizable().scaledToFill()
            } else {
                ZStack {
                    style.secondarySurface
                    Image(systemName: "person.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(style.secondaryText.opacity(0.75))
                }
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(style.surface, lineWidth: 5)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)
        .accessibilityLabel("\(profile.name)的头像")
    }

    private var profileDetails: some View {
        VStack(spacing: 10) {
            Text(profile.name)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.6)
                .foregroundStyle(style.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = profile.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(style.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let relationship = profile.relationshipLabel, !relationship.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(relationship)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(style.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(style.accent.opacity(0.10), in: Capsule())
                .padding(.top, 2)
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }

            if !profile.tags.isEmpty {
                FlowTags(tags: profile.tags, accent: style.accent, secondaryText: style.secondaryText, surface: style.secondarySurface)
                    .padding(.top, 5)
            }

            if !profile.stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(profile.stats.enumerated()), id: \.element.id) { index, stat in
                        if index > 0 {
                            Rectangle().fill(style.border).frame(width: 1, height: 30)
                        }
                        VStack(spacing: 4) {
                            Text(stat.value)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(style.primaryText)
                            Text(stat.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(style.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
                .background(style.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    HStack(spacing: 9) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text(primaryActionTitle)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(style.accent.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(ContactCardPressStyle())
                .accessibilityHint("进入与角色的聊天")
            }

            if let secondaryActionTitle, let onSecondaryAction {
                Button(action: onSecondaryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text(secondaryActionTitle)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(style.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(style.secondarySurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ContactCardPressStyle())
                .accessibilityHint("查看角色发布的动态")
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.top, 24)
    }
}

private struct FlowTags: View {
    let tags: [String]
    let accent: Color
    let secondaryText: Color
    let surface: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) { tagViews }
            VStack(spacing: 7) {
                ForEach(Array(tags.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 7) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, tag in tagView(tag) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var tagViews: some View {
        ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in tagView(tag) }
    }

    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(surface, in: Capsule())
            .lineLimit(1)
    }
}

private struct ContactCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}

#Preview("AI Companion Contact Card") {
    ZStack {
        Color.black.opacity(0.06).ignoresSafeArea()
        ContactCard(
            profile: .init(
                name: "林知夏",
                subtitle: "你的专属 AI 恋人 · 设计师",
                bio: "喜欢在深夜听歌，也喜欢认真听你讲今天发生的小事。",
                avatar: Image(systemName: "person.crop.square.fill"),
                isOnline: true,
                relationshipLabel: "恋爱中 · 相识 28 天",
                tags: ["温柔", "有一点傲娇", "深夜聊天"],
                stats: [.init(value: "28 天", label: "相伴"), .init(value: "126", label: "条动态"), .init(value: "∞", label: "心动指数")]
            ),
            onPrimaryAction: {},
            onSecondaryAction: {},
            onClose: {}
        )
        .padding(.vertical, 12)
    }
}
