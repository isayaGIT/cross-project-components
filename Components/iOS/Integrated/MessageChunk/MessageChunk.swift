import SwiftUI

/// Composes a chat message row from the library's Avatar and MessageBubble components.
/// Screen-level views should use MessageChunk rather than positioning those primitives directly.
public struct MessageChunk<Content: View>: View {
    public enum Direction {
        case incoming
        case outgoing
    }

    public struct Configuration {
        public var incomingAvatar: Avatar.Configuration
        public var outgoingAvatar: Avatar.Configuration
        public var incomingBubble: MessageBubble<AnyView>.Configuration
        public var outgoingBubble: MessageBubble<AnyView>.Configuration
        public var avatarBubbleSpacing: CGFloat
        public var showsAvatar: Bool
        public var incomingTextColor: Color
        public var outgoingTextColor: Color

        public init(
            incomingAvatar: Avatar.Configuration = .init(width: 34, height: 34),
            outgoingAvatar: Avatar.Configuration = .init(width: 34, height: 34),
            incomingBubble: MessageBubble<AnyView>.Configuration = .init(
                sharpCorner: .bottomLeading,
                style: .roundedTail,
                fill: AnyShapeStyle(Color.primary.opacity(0.055)),
                metadataAlignment: .leading,
                timestampColor: .secondary,
                font: .system(size: 16)
            ),
            outgoingBubble: MessageBubble<AnyView>.Configuration = .init(
                sharpCorner: .bottomTrailing,
                style: .roundedTail,
                fill: AnyShapeStyle(Color.accentColor),
                metadataAlignment: .trailing,
                timestampColor: .secondary,
                font: .system(size: 16)
            ),
            avatarBubbleSpacing: CGFloat = 8,
            showsAvatar: Bool = true,
            incomingTextColor: Color = .primary,
            outgoingTextColor: Color = .white
        ) {
            self.incomingAvatar = incomingAvatar
            self.outgoingAvatar = outgoingAvatar
            self.incomingBubble = incomingBubble
            self.outgoingBubble = outgoingBubble
            self.avatarBubbleSpacing = avatarBubbleSpacing
            self.showsAvatar = showsAvatar
            self.incomingTextColor = incomingTextColor
            self.outgoingTextColor = outgoingTextColor
        }

        /// ScreenChat's current appearance, centralized as MessageChunk defaults.
        public static func screenChat(colorScheme: ColorScheme) -> Self {
            let placeholder = Avatar.PlaceholderStyle(
                background: Color.accentColor.opacity(0.14),
                foreground: Color.accentColor
            )
            var incomingAvatar = Avatar.Configuration(width: 34, height: 34, shape: .circle, placeholderStyle: placeholder)
            var outgoingAvatar = incomingAvatar
            incomingAvatar.pokeEnabled = false
            outgoingAvatar.pokeEnabled = false
            var incomingBubble = MessageBubble<AnyView>.Configuration(
                sharpCorner: .bottomLeading,
                style: .roundedTail,
                fill: AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.055)),
                metadataAlignment: .leading,
                timestampColor: .secondary,
                font: .system(size: 16)
            )
            incomingBubble.timestampFont = .caption2
            var outgoingBubble = MessageBubble<AnyView>.Configuration(
                sharpCorner: .bottomTrailing,
                style: .roundedTail,
                fill: AnyShapeStyle(Color.accentColor),
                metadataAlignment: .trailing,
                timestampColor: .secondary,
                font: .system(size: 16)
            )
            outgoingBubble.timestampFont = .caption2
            return Self(
                incomingAvatar: incomingAvatar,
                outgoingAvatar: outgoingAvatar,
                incomingBubble: incomingBubble,
                outgoingBubble: outgoingBubble,
                avatarBubbleSpacing: 8,
                showsAvatar: true,
                incomingTextColor: colorScheme == .dark ? Color.white : Color.primary,
                outgoingTextColor: .white
            )
        }
    }

    private let direction: Direction
    private let avatar: Image?
    private let incomingAvatar: Image?
    private let timestamp: String?
    private let configuration: Configuration
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    public init(
        direction: Direction,
        avatar: Image? = nil,
        incomingAvatar: Image? = nil,
        timestamp: String? = nil,
        configuration: Configuration? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.direction = direction
        self.avatar = avatar
        self.incomingAvatar = incomingAvatar
        self.timestamp = timestamp
        self.configuration = configuration ?? .screenChat(colorScheme: .light)
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: configuration.avatarBubbleSpacing) {
            if direction == .outgoing {
                Spacer(minLength: 0)
                bubble(isOutgoing: true)
                if configuration.showsAvatar {
                    Avatar(image: avatar, configuration: configuration.outgoingAvatar)
                        .offset(y: -2)
                }
            } else {
                if configuration.showsAvatar {
                    Avatar(image: incomingAvatar ?? avatar, configuration: configuration.incomingAvatar)
                        .offset(y: -2)
                }
                bubble(isOutgoing: false)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bubble(isOutgoing: Bool) -> some View {
        let base = isOutgoing ? configuration.outgoingBubble : configuration.incomingBubble
        let resolved = MessageBubble<AnyView>.Configuration(
            cornerRadius: base.cornerRadius,
            sharpCorner: base.sharpCorner,
            style: base.style,
            fill: base.fill,
            border: base.border,
            padding: base.padding,
            width: base.width,
            height: base.height,
            alignment: base.alignment,
            timestamp: timestamp,
            metadataAlignment: base.metadataAlignment,
            timestampColor: base.timestampColor,
            timestampFont: base.timestampFont,
            font: base.font,
            lineSpacing: base.lineSpacing
        )
        if isOutgoing {
            MessageBubble<AnyView>(configuration: resolved) {
                AnyView(content.foregroundStyle(configuration.outgoingTextColor))
            }
        } else {
            MessageBubble<AnyView>(configuration: resolved) {
                AnyView(content.foregroundStyle(configuration.incomingTextColor))
            }
        }
    }
}
