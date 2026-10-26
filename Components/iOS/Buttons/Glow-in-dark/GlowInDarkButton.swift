import SwiftUI

/// A dark, glass-like pill button with a silver edge reflection and luminous label.
///
/// The component intentionally does not impose a background. Place it on a dark
/// surface for the closest match to the original reference.
public struct GlowInDarkButton: View {
    public let title: String
    public let width: CGFloat
    public let height: CGFloat
    private let action: () -> Void

    @State private var glowIsRaised = false

    public init(
        _ title: String = "Get Started",
        width: CGFloat = 240,
        height: CGFloat = 78,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.width = max(1, width.isFinite ? width : 240)
        self.height = max(1, height.isFinite ? height : 78)
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Wide, low-contrast bloom behind the glass body.
                Capsule()
                    .fill(Color.white.opacity(glowIsRaised ? 0.19 : 0.115))
                    .frame(width: width * 1.19, height: height * 0.92)
                    .blur(radius: height * 0.43)
                    .offset(x: width * 0.015, y: height * 0.08)

                Capsule()
                    .fill(Color.white.opacity(glowIsRaised ? 0.13 : 0.07))
                    .frame(width: width * 1.04, height: height * 0.78)
                    .blur(radius: height * 0.19)

                glassBody

                // Small, irregular pin-point reflections visible in the source art.
                sparkle(size: 1.45).position(x: width * 0.34, y: height * 0.64)
                sparkle(size: 1.1).position(x: width * 0.67, y: height * 0.78)
                sparkle(size: 0.9).position(x: width * 0.77, y: height * 0.20)

                Text(title)
                    .font(.system(size: height * 0.35, weight: .regular, design: .default))
                    .tracking(-height * 0.008)
                    .foregroundStyle(Color.white.opacity(0.98))
                    .shadow(color: .white.opacity(0.92), radius: height * 0.055)
                    .shadow(color: .white.opacity(0.48), radius: height * 0.15)
                    .shadow(color: .white.opacity(0.20), radius: height * 0.28)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, width * 0.12)
            }
            .frame(width: width, height: height)
            .contentShape(Capsule())
        }
        .buttonStyle(GlowInDarkPressStyle())
        .accessibilityLabel(title)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowIsRaised = true
            }
        }
    }

    private var glassBody: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.005, green: 0.005, blue: 0.008), location: 0),
                            .init(color: Color(red: 0.018, green: 0.018, blue: 0.021), location: 0.25),
                            .init(color: Color(red: 0.075, green: 0.075, blue: 0.079), location: 0.57),
                            .init(color: Color(red: 0.12, green: 0.12, blue: 0.125), location: 0.80),
                            .init(color: Color(red: 0.025, green: 0.025, blue: 0.028), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.045), .white.opacity(0.015), .black.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(height * 0.035)

            // The broad specular reflection bends around the right cap, rather than
            // outlining the entire capsule with a uniform white stroke.
            GlowInDarkRightReflection()
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.08), location: 0),
                            .init(color: .white.opacity(0.78), location: 0.20),
                            .init(color: .white.opacity(0.95), location: 0.48),
                            .init(color: .white.opacity(0.38), location: 0.74),
                            .init(color: .white.opacity(0.86), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: max(0.8, height * 0.025), lineCap: .round, lineJoin: .round)
                )
                .blur(radius: height * 0.012)

            GlowInDarkRightReflection()
                .stroke(Color.white.opacity(glowIsRaised ? 0.80 : 0.58), lineWidth: max(0.45, height * 0.009))
                .blur(radius: height * 0.004)

            // Curved, smoky reflection inside the right-hand glass cap.
            GlowInDarkInnerReflection()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.035),
                            .white.opacity(glowIsRaised ? 0.22 : 0.13),
                            .white.opacity(0.035),
                            .white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: height * 0.045)
                .clipShape(Capsule())

            GlowInDarkInnerHighlight()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(glowIsRaised ? 0.36 : 0.22), .white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: max(1.2, height * 0.065), lineCap: .round, lineJoin: .round)
                )
                .blur(radius: height * 0.035)
                .clipShape(Capsule())

            Capsule()
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0),
                            .init(color: .white.opacity(0.015), location: 0.42),
                            .init(color: .white.opacity(0.12), location: 0.70),
                            .init(color: .white.opacity(0.24), location: 0.92),
                            .init(color: .white.opacity(0.12), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.45, height * 0.008)
                )
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.54),
                            .init(color: .white.opacity(0.35), location: 0.68),
                            .init(color: .white, location: 0.84),
                            .init(color: .white, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.9), radius: height * 0.12, x: 0, y: height * 0.035)
    }

    private func sparkle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(glowIsRaised ? 0.95 : 0.62))
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.9), radius: height * 0.025)
    }
}

private struct GlowInDarkPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct GlowInDarkRightReflection: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.59, y: h * 0.025))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.025))
        path.addCurve(
            to: CGPoint(x: w * 0.985, y: h * 0.49),
            control1: CGPoint(x: w * 0.94, y: h * 0.02),
            control2: CGPoint(x: w * 0.985, y: h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.80, y: h * 0.975),
            control1: CGPoint(x: w * 0.985, y: h * 0.80),
            control2: CGPoint(x: w * 0.94, y: h * 0.98)
        )
        path.addLine(to: CGPoint(x: w * 0.57, y: h * 0.975))
        return path
    }
}

private struct GlowInDarkInnerReflection: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.73, y: h * 0.04))
        path.addCurve(
            to: CGPoint(x: w * 0.89, y: h * 0.37),
            control1: CGPoint(x: w * 0.84, y: h * 0.07),
            control2: CGPoint(x: w * 0.84, y: h * 0.19)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.48),
            control1: CGPoint(x: w * 0.93, y: h * 0.40),
            control2: CGPoint(x: w * 0.96, y: h * 0.43)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.83, y: h * 0.88),
            control1: CGPoint(x: w * 0.93, y: h * 0.66),
            control2: CGPoint(x: w * 0.89, y: h * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.96),
            control1: CGPoint(x: w * 0.78, y: h * 0.95),
            control2: CGPoint(x: w * 0.75, y: h * 0.96)
        )
        path.closeSubpath()
        return path
    }
}

/// A standalone preview surface approximating the black grid backdrop in the reference.
/// It is separate from `GlowInDarkButton` so the reusable control never owns its parent's background.
public struct GlowInDarkButtonShowcase: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                GlowInDarkGrid()
                    .stroke(Color.white.opacity(0.035), lineWidth: 0.55)
                    .frame(width: proxy.size.width * 0.64, height: proxy.size.height * 0.52)
                    .mask {
                        LinearGradient(colors: [.clear, .white, .white.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom)
                    }
                GlowInDarkButton(width: min(proxy.size.width * 0.30, 300), height: min(proxy.size.width * 0.10, 84))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .preferredColorScheme(.dark)
    }
}


private struct GlowInDarkInnerHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.84, y: h * 0.12))
        path.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.39),
            control1: CGPoint(x: w * 0.91, y: h * 0.18),
            control2: CGPoint(x: w * 0.87, y: h * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.54),
            control1: CGPoint(x: w * 0.94, y: h * 0.45),
            control2: CGPoint(x: w * 0.95, y: h * 0.49)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.82),
            control1: CGPoint(x: w * 0.91, y: h * 0.66),
            control2: CGPoint(x: w * 0.88, y: h * 0.76)
        )
        return path
    }
}

private struct GlowInDarkGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 42
        stride(from: CGFloat.zero, through: rect.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        stride(from: CGFloat.zero, through: rect.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

#Preview("Glow in Dark") {
    GlowInDarkButtonShowcase()
        .frame(width: 390, height: 320)
}
