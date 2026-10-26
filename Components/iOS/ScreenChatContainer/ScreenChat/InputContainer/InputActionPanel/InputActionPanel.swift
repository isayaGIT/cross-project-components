import SwiftUI

/// A reusable grid of actions shown from the chat input's Add button.
/// The parent container owns presentation state; this view only renders actions.
public struct InputActionPanel: View {
    public struct Action: Identifiable {
        public let id: String
        public let title: String
        public let systemImage: String
        public let accessibilityLabel: String
        private let handler: () -> Void

        public init(
            id: String,
            title: String,
            systemImage: String,
            accessibilityLabel: String? = nil,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.accessibilityLabel = accessibilityLabel ?? title
            self.handler = action
        }

        fileprivate func perform() { handler() }
    }

    private let actions: [Action]
    private let columns: Int
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat
    private let iconSize: CGFloat
    private let configuration: Configuration

    public struct Configuration {
        public var panelBackground: AnyShapeStyle
        public var tileBackground: AnyShapeStyle
        public var foregroundColor: Color
        public var secondaryColor: Color
        public var cornerRadius: CGFloat
        public var iconFont: Font
        public var titleFont: Font
        public var minimumTileHeight: CGFloat
        public var horizontalPadding: CGFloat
        public var verticalPadding: CGFloat

        public init(
            panelBackground: AnyShapeStyle = AnyShapeStyle(.regularMaterial),
            tileBackground: AnyShapeStyle = AnyShapeStyle(Color.secondary.opacity(0.08)),
            foregroundColor: Color = .primary,
            secondaryColor: Color = .secondary,
            cornerRadius: CGFloat = 18,
            iconFont: Font = .system(size: 22, weight: .regular),
            titleFont: Font = .system(size: 12, weight: .medium),
            minimumTileHeight: CGFloat = 76,
            horizontalPadding: CGFloat = 16,
            verticalPadding: CGFloat = 16
        ) {
            self.panelBackground = panelBackground
            self.tileBackground = tileBackground
            self.foregroundColor = foregroundColor
            self.secondaryColor = secondaryColor
            self.cornerRadius = cornerRadius
            self.iconFont = iconFont
            self.titleFont = titleFont
            self.minimumTileHeight = minimumTileHeight
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
        }

        public static let standard = Configuration()
    }

    public init(
        actions: [Action],
        columns: Int = 4,
        horizontalSpacing: CGFloat = 12,
        verticalSpacing: CGFloat = 12,
        iconSize: CGFloat = 22,
        configuration: Configuration = .standard
    ) {
        self.actions = actions
        self.columns = max(1, columns)
        self.horizontalSpacing = max(0, horizontalSpacing)
        self.verticalSpacing = max(0, verticalSpacing)
        self.iconSize = max(1, iconSize)
        self.configuration = configuration
    }

    public var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: horizontalSpacing, alignment: .top), count: columns),
            alignment: .center,
            spacing: verticalSpacing
        ) {
            ForEach(actions) { action in
                Button(action: action.perform) {
                    VStack(spacing: 9) {
                        Image(systemName: action.systemImage)
                            .font(configuration.iconFont)
                            .foregroundStyle(configuration.foregroundColor)
                            .frame(height: iconSize + 4)

                        Text(action.title)
                            .font(configuration.titleFont)
                            .foregroundStyle(configuration.secondaryColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: configuration.minimumTileHeight)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                            .fill(configuration.tileBackground)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.accessibilityLabel)
            }
        }
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, configuration.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: configuration.cornerRadius + 4, style: .continuous)
                .fill(configuration.panelBackground)
        }
    }
}
