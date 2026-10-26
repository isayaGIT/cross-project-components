import SwiftUI

/// Configurable dashed selection outline for reusable canvas nodes.
public struct CanvasNodeSelectionBorder: View {
    public var color: Color
    public var lineLength: CGFloat
    public var lineSpacing: CGFloat
    public var weight: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var cornerRadius: CGFloat

    public init(
        color: Color = Color(red: 0.95, green: 0.46, blue: 0.83),
        lineLength: CGFloat = 4,
        lineSpacing: CGFloat = 3,
        weight: CGFloat = 1,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 3
    ) {
        self.color = color
        self.lineLength = max(0, lineLength)
        self.lineSpacing = max(0, lineSpacing)
        self.weight = max(0, weight)
        self.width = max(0, width)
        self.height = max(0, height)
        self.cornerRadius = max(0, cornerRadius)
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color, style: StrokeStyle(lineWidth: weight, dash: [lineLength, lineSpacing]))
            .frame(width: width, height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
