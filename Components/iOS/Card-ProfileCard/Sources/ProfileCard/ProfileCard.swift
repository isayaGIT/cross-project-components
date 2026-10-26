import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A reusable, presentation-only profile card for the current user or a character.
/// The host supplies resolved images, recent media, and action handlers.
public struct ProfileCard: View {
    public struct RecentMoment: Identifiable {
        public let id: String
        public var thumbnail: Image
        public var isVideo: Bool
        public var accessibilityLabel: String?

        public init(id: String = UUID().uuidString, thumbnail: Image, isVideo: Bool = false, accessibilityLabel: String? = nil) {
            self.id = id
            self.thumbnail = thumbnail
            self.isVideo = isVideo
            self.accessibilityLabel = accessibilityLabel
        }
    }

    public enum Status: String, CaseIterable, Identifiable {
        case online, offline, replying, error
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .online: "在线"
            case .offline: "离线"
            case .replying: "正在输入..."
            case .error: "出错了!"
            }
        }
        public var color: Color {
            switch self {
            case .online: .green
            case .offline: .gray
            case .replying: .yellow
            case .error: .red
            }
        }
    }

    public struct Profile {
        public var name: String
        public var signature: String
        public var status: Status
        public var profileImage: Image?
        public var profileBackgroundImage: Image?
        public var cardBackgroundImage: Image?
        /// Only image/video moments should be passed here; the view displays at most four.
        public var recentMoments: [RecentMoment]

        public init(
            name: String,
            signature: String = "",
            status: Status = .online,
            profileImage: Image? = nil,
            profileBackgroundImage: Image? = nil,
            cardBackgroundImage: Image? = nil,
            recentMoments: [RecentMoment] = []
        ) {
            self.name = name
            self.signature = signature
            self.status = status
            self.profileImage = profileImage
            self.profileBackgroundImage = profileBackgroundImage
            self.cardBackgroundImage = cardBackgroundImage
            self.recentMoments = recentMoments
        }
    }

    /// Typography, surfaces, and accent colors. Higher group numbers are secondary accents.
    public struct Style {
        public var nameFontName: String?
        public var nameFontSize: CGFloat
        public var nameColor: Color
        public var signatureFontName: String?
        public var signatureFontSize: CGFloat
        public var signatureColor: Color
        public var statusFontName: String?
        public var statusFontSize: CGFloat
        public var group1: Color
        public var group2: Color
        public var group3: Color
        public var group4: Color
        public var group5: Color
        public var cardColor: Color
        public var cornerRadius: CGFloat
        public var coverHeight: CGFloat
        public var avatarSize: CGFloat
        public var actionFontName: String?
        public var actionFontSize: CGFloat
        public var actionTextColor: Color
        public var actionBackgroundColor: Color
        public var voiceCallBackgroundColor: Color
        public var listenTogetherBackgroundColor: Color
        public var momentSize: CGFloat

        public init(
            nameFontName: String? = nil,
            nameFontSize: CGFloat = 23,
            nameColor: Color = .primary,
            signatureFontName: String? = nil,
            signatureFontSize: CGFloat = 13,
            signatureColor: Color = .secondary,
            statusFontName: String? = nil,
            statusFontSize: CGFloat = 12,
            group1: Color = .pink,
            group2: Color = .purple,
            group3: Color = .blue,
            group4: Color = .orange,
            group5: Color = .green,
            cardColor: Color? = nil,
            cornerRadius: CGFloat = 24,
            coverHeight: CGFloat = 156,
            avatarSize: CGFloat = 88,
            actionFontName: String? = nil,
            actionFontSize: CGFloat = 14,
            actionTextColor: Color = .white,
            actionBackgroundColor: Color? = nil,
            voiceCallBackgroundColor: Color? = nil,
            listenTogetherBackgroundColor: Color? = nil,
            momentSize: CGFloat = 64
        ) {
            self.nameFontName = nameFontName
            self.nameFontSize = max(1, nameFontSize)
            self.nameColor = nameColor
            self.signatureFontName = signatureFontName
            self.signatureFontSize = max(1, signatureFontSize)
            self.signatureColor = signatureColor
            self.statusFontName = statusFontName
            self.statusFontSize = max(1, statusFontSize)
            self.group1 = group1
            self.group2 = group2
            self.group3 = group3
            self.group4 = group4
            self.group5 = group5
            self.cardColor = cardColor ?? Self.platformCardColor
            self.cornerRadius = max(0, cornerRadius)
            self.coverHeight = max(0, coverHeight)
            self.avatarSize = max(1, avatarSize)
            self.actionFontName = actionFontName
            self.actionFontSize = max(1, actionFontSize)
            self.actionTextColor = actionTextColor
            self.actionBackgroundColor = actionBackgroundColor ?? group1
            self.voiceCallBackgroundColor = voiceCallBackgroundColor ?? group2
            self.listenTogetherBackgroundColor = listenTogetherBackgroundColor ?? group3
            self.momentSize = max(1, momentSize)
        }

        public static let `default` = Style()

        private static var platformCardColor: Color {
            #if canImport(UIKit)
            return Color(uiColor: .secondarySystemBackground)
            #elseif canImport(AppKit)
            return Color(nsColor: .windowBackgroundColor)
            #else
            return Color.gray.opacity(0.08)
            #endif
        }

        fileprivate var nameFont: Font {
            if let nameFontName, !nameFontName.isEmpty { return .custom(nameFontName, size: nameFontSize).weight(.bold) }
            return .system(size: nameFontSize, weight: .bold, design: .rounded)
        }

        fileprivate var signatureFont: Font {
            if let signatureFontName, !signatureFontName.isEmpty { return .custom(signatureFontName, size: signatureFontSize) }
            return .system(size: signatureFontSize)
        }

        fileprivate var actionFont: Font {
            if let actionFontName, !actionFontName.isEmpty { return .custom(actionFontName, size: actionFontSize).weight(.semibold) }
            return .system(size: actionFontSize, weight: .semibold)
        }
    }

    private let profile: Profile
    private let style: Style
    private let onVoiceCall: (() -> Void)?
    private let onListenTogether: (() -> Void)?
    private let onMessage: (() -> Void)?
    private let thumbnailRenderer: ((RecentMoment, CGFloat) -> AnyView)?

    public init(
        profile: Profile,
        style: Style = .default,
        onVoiceCall: (() -> Void)? = nil,
        onListenTogether: (() -> Void)? = nil,
        onMessage: (() -> Void)? = nil,
        thumbnailRenderer: ((RecentMoment, CGFloat) -> AnyView)? = nil
    ) {
        self.profile = profile
        self.style = style
        self.onVoiceCall = onVoiceCall
        self.onListenTogether = onListenTogether
        self.onMessage = onMessage
        self.thumbnailRenderer = thumbnailRenderer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            profileDetails
            recentMoments
            actionPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let image = profile.cardBackgroundImage { image.resizable().scaledToFill() }
            else { style.cardColor }
        }
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(style.group2.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 14)
        .accessibilityElement(children: .contain)
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = profile.profileBackgroundImage {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [style.group1.opacity(0.9), style.group2.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.coverHeight)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.16)], startPoint: .center, endPoint: .bottom)
                .frame(height: style.coverHeight)

            avatar
                .padding(.leading, 20)
                .offset(y: style.avatarSize * 0.42)
        }
        .padding(.bottom, style.avatarSize * 0.42)
    }

    private var avatar: some View {
        Group {
            if let image = profile.profileImage {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    style.group1.opacity(0.12)
                    Image(systemName: "person.fill")
                        .font(.system(size: style.avatarSize * 0.42, weight: .light))
                        .foregroundStyle(style.group1)
                }
            }
        }
        .frame(width: style.avatarSize, height: style.avatarSize)
        .clipShape(RoundedRectangle(cornerRadius: style.avatarSize * 0.28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.avatarSize * 0.28, style: .continuous)
                .strokeBorder(style.cardColor, lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        .accessibilityLabel("\(profile.name)的头像")
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                #if !PROFILECARD_STANDALONE
                CharacterName(profile.name, style: .init(fontName: style.nameFontName, fontSize: style.nameFontSize, color: style.nameColor, weight: .bold))
                #else
                Text(profile.name)
                    .font(style.nameFont)
                    .foregroundStyle(style.nameColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
                Spacer(minLength: 4)
                #if !PROFILECARD_STANDALONE
                CharacterStatus(
                    CharacterStatusState(rawValue: profile.status.rawValue) ?? .online,
                    fontName: style.statusFontName,
                    fontSize: style.statusFontSize
                )
                #else
                HStack(spacing: 5) {
                    Circle().fill(profile.status.color).frame(width: 6, height: 6)
                    Text(profile.status.title)
                        .font(style.statusFontName.map { Font.custom($0, size: style.statusFontSize) } ?? .system(size: style.statusFontSize, weight: .medium))
                        .foregroundStyle(profile.status.color)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                #endif
            }

            if !profile.signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(profile.signature)
                    .font(style.signatureFont)
                    .foregroundStyle(style.signatureColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recentMoments: some View {
        let moments = Array(profile.recentMoments.prefix(4))
        if !moments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("最近动态")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(style.signatureColor)

                HStack(spacing: 8) {
                    ForEach(moments) { moment in
                        momentThumbnail(moment)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    private func momentThumbnail(_ moment: RecentMoment) -> some View {
        ZStack(alignment: .center) {
            if let thumbnailRenderer {
                thumbnailRenderer(moment, style.momentSize)
            } else {
                #if !PROFILECARD_STANDALONE
                ImgThumbnail(image: moment.thumbnail, size: CGSize(width: style.momentSize, height: style.momentSize), shape: .square)
                #else
                moment.thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: style.momentSize, height: style.momentSize)
                    .clipped()
                #endif
            }
            if moment.isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
        }
        .frame(width: style.momentSize, height: style.momentSize)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(moment.accessibilityLabel ?? (moment.isVideo ? "视频动态" : "图片动态"))
    }

    private var actionPanel: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                compactAction(title: "语音通话", systemImage: "phone", background: style.voiceCallBackgroundColor, action: onVoiceCall)
                    .frame(width: max(78, (geometry.size.width - 16) * 0.22), height: 42)

                compactAction(title: "一起听", systemImage: "headphones", background: style.listenTogetherBackgroundColor, action: onListenTogether)
                    .frame(width: max(68, (geometry.size.width - 16) * 0.20), height: 42)

                Button { onMessage?() } label: {
                    Text("发消息")
                        .font(style.actionFont)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(style.actionBackgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .disabled(onMessage == nil)
                .opacity(onMessage == nil ? 0.65 : 1)
            }
            .foregroundStyle(style.actionTextColor)
        }
        .frame(height: 42)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func compactAction(title: String, systemImage: String, background: Color, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(style.actionFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(action == nil)
        .opacity(action == nil ? 0.65 : 1)
    }
}
