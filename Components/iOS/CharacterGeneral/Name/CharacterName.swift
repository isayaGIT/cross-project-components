import SwiftUI

/// Reusable typography for a character or user name.
public struct CharacterName: View {
    public struct Style {
        public var fontName: String?
        public var fontSize: CGFloat
        public var color: Color
        public var weight: Font.Weight

        public init(fontName: String? = nil, fontSize: CGFloat = 17, color: Color = .primary, weight: Font.Weight = .semibold) {
            self.fontName = fontName
            self.fontSize = max(1, fontSize)
            self.color = color
            self.weight = weight
        }
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .init()) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(resolvedFont)
            .foregroundStyle(style.color)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }

    private var resolvedFont: Font {
        if let name = style.fontName, !name.isEmpty {
            return .custom(name, size: style.fontSize).weight(style.weight)
        }
        return .system(size: style.fontSize, weight: style.weight)
    }
}
