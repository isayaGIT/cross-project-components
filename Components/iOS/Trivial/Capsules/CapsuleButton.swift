import SwiftUI

/// A borderless, action-oriented text capsule with a continuous rounded-rectangle shape.
public struct CapsuleButton: View {
    private let title: String
    private let background: Color
    private let foreground: Color
    private let cornerRadius: CGFloat
    private let padding: EdgeInsets
    private let font: Font
    private let action: () -> Void

    public init(
        _ title: String,
        background: Color = Color.primary.opacity(0.07),
        foreground: Color = .primary,
        cornerRadius: CGFloat = 18,
        padding: EdgeInsets = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14),
        font: Font = .system(size: 14, weight: .medium),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.background = background
        self.foreground = foreground
        self.cornerRadius = max(0, cornerRadius)
        self.padding = padding
        self.font = font
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(foreground)
                .padding(padding)
                .fixedSize(horizontal: true, vertical: false)
                .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
