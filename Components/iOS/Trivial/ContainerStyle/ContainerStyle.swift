import SwiftUI

/// Reusable visual treatment for a container edge or background region.
/// It changes only the fill; sizing and clipping remain the caller's responsibility.
public struct ContainerStyle: View {
    public enum Style {
        case black
        case blur
        case capsule(material: Material = .ultraThinMaterial, width: CGFloat = 0.9)
        case color(Color)
        case gradient(Gradient)
    }

    /// The direction in which the effect progresses.
    public enum Direction {
        case topToBottom
        case bottomToTop
        case leadingToTrailing
        case trailingToLeading
    }

    private let height: CGFloat
    private let style: Style
    private let direction: Direction

    public init(height: CGFloat, style: Style = .black, direction: Direction = .bottomToTop) {
        self.height = max(0, height)
        self.style = style
        self.direction = direction
    }

    public var body: some View {
        Group {
            if case .capsule(let material, let width) = style {
                GeometryReader { geometry in
                    Capsule()
                        .fill(material)
                        // Keep the container slightly more transparent than its controls.
                        .opacity(0.82)
                        .overlay {
                            Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                        }
                        .frame(width: resolvedCapsuleWidth(width, availableWidth: geometry.size.width), height: height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: height)
            } else {
                effect
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func resolvedCapsuleWidth(_ width: CGFloat, availableWidth: CGFloat) -> CGFloat {
        guard width > 0 else { return max(0, availableWidth) }
        return max(0, min(width <= 1 ? availableWidth * width : width, availableWidth))
    }

    @ViewBuilder
    private var effect: some View {
        switch style {
        case .black:
            Rectangle().fill(LinearGradient(colors: gradientColors(for: .black), startPoint: startPoint, endPoint: endPoint))
        case .blur:
            // Material itself is uniform; the mask gives it a soft directional fade.
            Rectangle().fill(.ultraThinMaterial)
                .mask { LinearGradient(colors: maskColors, startPoint: startPoint, endPoint: endPoint) }
        case .capsule:
            EmptyView()
        case .color(let color):
            Rectangle().fill(LinearGradient(colors: gradientColors(for: color), startPoint: startPoint, endPoint: endPoint))
        case .gradient(let gradient):
            Rectangle().fill(LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
        }
    }

    private var maskColors: [Color] {
        switch direction {
        case .topToBottom, .leadingToTrailing: return [.black, .clear]
        case .bottomToTop, .trailingToLeading: return [.black, .clear]
        }
    }

    private func gradientColors(for color: Color) -> [Color] {
        switch direction {
        case .topToBottom, .leadingToTrailing: return [color, color.opacity(0)]
        case .bottomToTop, .trailingToLeading: return [color.opacity(0), color]
        }
    }

    private var startPoint: UnitPoint {
        switch direction {
        case .topToBottom: return .top
        case .bottomToTop: return .bottom
        case .leadingToTrailing: return .leading
        case .trailingToLeading: return .trailing
        }
    }

    private var endPoint: UnitPoint {
        switch direction {
        case .topToBottom: return .bottom
        case .bottomToTop: return .top
        case .leadingToTrailing: return .trailing
        case .trailingToLeading: return .leading
        }
    }
}
