import SwiftUI
import LineDashed

@main
struct LineDashedShowcaseApp: App {
    var body: some Scene {
        WindowGroup { ShowcaseView() }
    }
}

private struct ShowcaseView: View {
    @State private var lineWidth: Double = 4
    @State private var dashLength: Double = 12
    @State private var spacing: Double = 6
    @State private var radius: Double = 2
    @State private var isAnimating = false
    @State private var phase: CGFloat = 0
    @State private var useGradient = true
    @State private var perSegment = false
    @State private var closedMode = true
    @State private var pathKind = 0

    private var configuration: DashedLineConfiguration {
        .init(lineWidth: lineWidth, dashLength: dashLength, dashSpacing: spacing, cornerRadius: radius,
              closedPathMode: closedMode ? .evenlyDistributed : .fixedLengthAndSpacing)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    VStack(spacing: 24) {
                        LineDashed(path: samplePath(in: CGRect(x: 12, y: 12, width: 280, height: 130)), configuration: configuration,
                                   fill: useGradient ? .linearGradient(Gradient(colors: [.cyan, .blue, .purple, .pink]), startPoint: .leading, endPoint: .trailing) : .color(.orange),
                                   fillCoordinates: perSegment ? .perSegment : .pathContinuous, phase: phase)
                            .frame(height: 160)
                        Text("Independent rounded-rectangle dash segments")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section("Path") {
                    Picker("Path type", selection: $pathKind) {
                        Text("Rectangle").tag(0)
                        Text("Rounded rectangle").tag(1)
                        Text("Curve").tag(2)
                    }
                    Toggle("Evenly distribute closed path", isOn: $closedMode)
                }
                Section("Geometry") {
                    slider("Line width", value: $lineWidth, range: 1...12)
                    slider("Dash length", value: $dashLength, range: 2...32)
                    slider("Dash spacing", value: $spacing, range: 0...20)
                    slider("Corner radius", value: $radius, range: 0...6)
                }
                Section("Fill") {
                    Toggle("Gradient", isOn: $useGradient)
                    Toggle("Restart fill on every segment", isOn: $perSegment)
                }
                Section("Animation") {
                    Toggle("Marching dashes", isOn: $isAnimating)
                    Text("Animation is opt-in; disable it for a static preview.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("LineDashed Showcase")
            .onChange(of: isAnimating) { _, active in if active { startAnimation() } }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text(value.wrappedValue, format: .number.precision(.fractionLength(1))).monospacedDigit() }
            Slider(value: value, in: range)
        }
    }

    private func samplePath(in rect: CGRect) -> Path {
        switch pathKind {
        case 0: return Path(rect)
        case 1: return Path(roundedRect: rect, cornerRadius: 28)
        default:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.minX + 70, y: rect.minY - 20), control2: CGPoint(x: rect.maxX - 70, y: rect.maxY + 20))
            return path
        }
    }

    private func startAnimation() {
        guard isAnimating else { return }
        withAnimation(.linear(duration: 0.05)) { phase += 1.5 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if isAnimating { startAnimation() }
        }
    }
}
