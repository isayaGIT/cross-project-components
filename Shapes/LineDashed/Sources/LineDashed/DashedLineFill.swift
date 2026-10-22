import SwiftUI

/// Fill choices supported by the first version of LineDashed.
public enum DashedLineFill {
    case color(Color)
    case linearGradient(Gradient, startPoint: UnitPoint, endPoint: UnitPoint)
    case radialGradient(Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat)
    case angularGradient(Gradient, center: UnitPoint, startAngle: Angle)
    case checkerboard(cellSize: CGFloat, first: Color, second: Color)
    case grid(cellSize: CGFloat, lineWidth: CGFloat, color: Color, background: Color)
}
