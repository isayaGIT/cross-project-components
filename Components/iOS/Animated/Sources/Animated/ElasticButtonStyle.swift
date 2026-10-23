import SwiftUI

/// Controls the squash and spring response of an elastic button.
public struct ElasticButtonConfiguration: Sendable {
    public var pressedScaleX: CGFloat
    public var pressedScaleY: CGFloat
    public var pressDuration: Double
    public var releaseDuration: Double
    public var releaseBounce: Double

    public init(
        pressedScaleX: CGFloat = 0.96,
        pressedScaleY: CGFloat = 0.88,
        pressDuration: Double = 0.12,
        releaseDuration: Double = 0.34,
        releaseBounce: Double = 0.32
    ) {
        self.pressedScaleX = Self.clamp(pressedScaleX, lower: 0.5, upper: 1.2, fallback: 0.96)
        self.pressedScaleY = Self.clamp(pressedScaleY, lower: 0.5, upper: 1.2, fallback: 0.88)
        self.pressDuration = Self.clamp(pressDuration, lower: 0, upper: 2, fallback: 0.12)
        self.releaseDuration = Self.clamp(releaseDuration, lower: 0.05, upper: 2, fallback: 0.34)
        self.releaseBounce = Self.clamp(releaseBounce, lower: 0, upper: 1, fallback: 0.32)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat, fallback: CGFloat) -> CGFloat {
        value.isFinite ? min(upper, max(lower, value)) : fallback
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double, fallback: Double) -> Double {
        value.isFinite ? min(upper, max(lower, value)) : fallback
    }

    public static let standard = ElasticButtonConfiguration()
}

/// A ButtonStyle with a soft squash while pressed and a springy release.
public struct ElasticButtonStyle: ButtonStyle {
    private let configuration: ElasticButtonConfiguration

    public init(configuration: ElasticButtonConfiguration = .standard) {
        self.configuration = configuration
    }

    public func makeBody(configuration button: Configuration) -> some View {
        button.label
            .scaleEffect(
                x: button.isPressed ? configuration.pressedScaleX : 1,
                y: button.isPressed ? configuration.pressedScaleY : 1,
                anchor: .center
            )
            .animation(
                button.isPressed
                    ? .easeOut(duration: configuration.pressDuration)
                    : .spring(duration: configuration.releaseDuration, bounce: configuration.releaseBounce),
                value: button.isPressed
            )
            .contentShape(Rectangle())
    }
}

public extension ButtonStyle where Self == ElasticButtonStyle {
    static var legacyElastic: ElasticButtonStyle { ElasticButtonStyle() }

    static func elastic(_ configuration: ElasticButtonConfiguration) -> ElasticButtonStyle {
        ElasticButtonStyle(configuration: configuration)
    }
}
