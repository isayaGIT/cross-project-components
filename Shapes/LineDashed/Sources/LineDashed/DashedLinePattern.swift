import SwiftUI

/// Built-in repeatable patterns. Pattern rendering uses the same coordinate mode as gradients.
public enum DashedLinePattern {
    case checkerboard(cellSize: CGFloat, first: Color, second: Color)
    case grid(cellSize: CGFloat, lineWidth: CGFloat, color: Color, background: Color)
}
