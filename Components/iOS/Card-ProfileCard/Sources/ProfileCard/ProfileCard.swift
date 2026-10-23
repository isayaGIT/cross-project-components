import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A reusable, presentation-only profile card for a person or a fictional character.
/// Image loading, data storage, navigation, and actions are owned by the host app.
public struct ProfileCard: View {
    public struct Profile {
        public var name: String
        public var signature: String
        public var profileImage: Image?
        public var profileBackgroundImage: Image?
        public var cardBackgroundImage: Image?

        public init(
            name: String,
            signature: String = "",
            profileImage: Image? = nil,
            profileBackgroundImage: Image? = nil,
            cardBackgroundImage: Image? = nil
        ) {
            self.name = name
            self.signature = signature
            self.profileImage = profileImage
            self.profileBackgroundImage = profileBackgroundImage
            self.cardBackgroundImage = cardBackgroundImage
        }
    }

    /// Text and theme colors. `group1` is the primary accent; `group2` is secondary.
    public struct Style {
        public var nameFontName: String?
        public var nameFontSize: CGFloat
        public var nameColor: Color
        public var signatureFontName: String?
        public var signatureFontSize: CGFloat
        public var signatureColor: Color
        public var group1: Color
        public var group2: Color
        public var cardColor: Color
        public var cornerRadius: CGFloat
        public var coverHeight: CGFloat
        public var avatarSize: CGFloat

        public init(
            nameFontName: String? = nil,
            nameFontSize: CGFloat = 23,
            nameColor: Color = .primary,
            signatureFontName: String? = nil,
            signatureFontSize: CGFloat = 13,
            signatureColor: Color = .secondary,
            group1: Color = .pink,
            group2: Color = .purple,
            cardColor: Color? = nil,
            cornerRadius: CGFloat = 24,
            coverHeight: CGFloat = 156,
            avatarSize: CGFloat = 88
        ) {
            self.nameFontName = nameFontName
            self.nameFontSize = max(1, nameFontSize)
            self.nameColor = nameColor
            self.signatureFontName = signatureFontName
            self.signatureFontSize = max(1, signatureFontSize)
            self.signatureColor = signatureColor
            self.group1 = group1
            self.group2 = group2
            self.cardColor = cardColor ?? Self.platformCardColor
            self.cornerRadius = max(0, cornerRadius)
            self.coverHeight = max(0, coverHeight)
            self.avatarSize = max(1, avatarSize)
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
            if let nameFontName, !nameFontName.isEmpty {
                return .custom(nameFontName, size: nameFontSize)
            }
            return .system(size: nameFontSize, weight: .bold, design: .rounded)
        }

        fileprivate var signatureFont: Font {
            if let signatureFontName, !signatureFontName.isEmpty {
                return .custom(signatureFontName, size: signatureFontSize)
            }
            return .system(size: signatureFontSize, weight: .regular)
        }
    }

    private let profile: Profile
    private let style: Style

    public init(profile: Profile, style: Style = .default) {
        self.profile = profile
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            profileDetails
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let image = profile.cardBackgroundImage {
                image.resizable().scaledToFill()
            } else {
                style.cardColor
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(style.group2.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = profile.profileBackgroundImage {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [style.group1.opacity(0.9), style.group2.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.coverHeight)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.16)],
                startPoint: .center,
                endPoint: .bottom
            )
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
            Text(profile.name)
                .font(style.nameFont)
                .foregroundStyle(style.nameColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

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
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
