import SwiftUI

/// Experimental SwiftUI port of the “Jade Sky” gradient from 21st.dev.
///
/// This imported component is intentionally kept under `Imports/background`
/// until its appearance has been tested. It has no third-party dependencies.
///
/// Usage:
/// `GradientBackground().frame(height: 440)`
///
/// Place it behind content in a `ZStack`; its size is controlled by its parent.
public struct GradientBackground: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let radius = max(size.width, size.height)

            ZStack {
                Color(red: 207 / 255, green: 233 / 255, blue: 240 / 255)

                RadialGradient(
                    colors: [
                        Color(red: 238 / 255, green: 246 / 255, blue: 227 / 255),
                        Color(red: 238 / 255, green: 246 / 255, blue: 227 / 255).opacity(0)
                    ],
                    center: UnitPoint(x: 0.6534, y: 0.4462),
                    startRadius: 0,
                    endRadius: radius * 0.72
                )

                RadialGradient(
                    colors: [
                        Color(red: 183 / 255, green: 217 / 255, blue: 142 / 255),
                        Color(red: 183 / 255, green: 217 / 255, blue: 142 / 255).opacity(0)
                    ],
                    center: UnitPoint(x: 0.2807, y: 0.7448),
                    startRadius: 0,
                    endRadius: radius * 0.82
                )

                RadialGradient(
                    colors: [
                        Color(red: 127 / 255, green: 191 / 255, blue: 154 / 255),
                        Color(red: 127 / 255, green: 191 / 255, blue: 154 / 255).opacity(0)
                    ],
                    center: UnitPoint(x: 0.5242, y: 0.1994),
                    startRadius: 0,
                    endRadius: radius * 0.98
                )

                RadialGradient(
                    colors: [
                        Color(red: 207 / 255, green: 233 / 255, blue: 240 / 255),
                        Color(red: 207 / 255, green: 233 / 255, blue: 240 / 255).opacity(0)
                    ],
                    center: UnitPoint(x: 0.8031, y: 0.8447),
                    startRadius: 0,
                    endRadius: radius * 1.08
                )
            }
            .frame(width: size.width, height: size.height)
            .blur(radius: min(size.width, size.height) * 0.004)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    GradientBackground()
        .frame(height: 440)
}
