import SwiftUI

/// Configurable tactile press feedback for any SwiftUI Button.
public struct PressedDownConfiguration: Sendable {
    public var scale: CGFloat
    public var opacity: CGFloat
    public var animationDuration: Double

    public init(scale: CGFloat = 0.96, opacity: CGFloat = 1, animationDuration: Double = 0.12) {
        self.scale = min(max(scale, 0.5), 1)
        self.opacity = min(max(opacity, 0), 1)
        self.animationDuration = max(0, animationDuration)
    }

    public static let standard = PressedDownConfiguration()
}

public struct PressedDownStyle: ButtonStyle {
    private let configuration: PressedDownConfiguration

    public init(configuration: PressedDownConfiguration = .standard) {
        self.configuration = configuration
    }

    public func makeBody(configuration button: Configuration) -> some View {
        button.label
            .scaleEffect(button.isPressed ? configuration.scale : 1)
            .opacity(button.isPressed ? configuration.opacity : 1)
            .animation(.easeOut(duration: configuration.animationDuration), value: button.isPressed)
            .contentShape(Rectangle())
    }
}

public extension ButtonStyle where Self == PressedDownStyle {
    static var pressedDown: PressedDownStyle { PressedDownStyle() }
    static func pressedDown(_ configuration: PressedDownConfiguration) -> PressedDownStyle {
        PressedDownStyle(configuration: configuration)
    }
}
