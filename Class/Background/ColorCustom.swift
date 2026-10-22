import SwiftUI

/// Reusable solid or gradient color style for component backgrounds and borders.
public struct ColorCustom: View {
    public enum Style {
        case solid(Color)
        case linearGradient(colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing)
        case radialGradient(colors: [Color], center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat = 300)
        case angularGradient(colors: [Color], center: UnitPoint = .center, startAngle: Angle = .degrees(0), endAngle: Angle = .degrees(360))
    }

    public let style: Style

    public init(_ color: Color) { self.style = .solid(color) }
    public init(style: Style) { self.style = style }

    @ViewBuilder public var body: some View {
        switch style {
        case .solid(let color): color
        case .linearGradient(let colors, let startPoint, let endPoint):
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
        case .angularGradient(let colors, let center, let startAngle, let endAngle):
            AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle)
        }
    }
}
