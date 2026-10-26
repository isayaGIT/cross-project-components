import SwiftUI

@main
struct LiquidBlobBarDemoApp: App {
    var body: some Scene {
        WindowGroup { LiquidBlobBarDemoView() }
    }
}

private struct LiquidBlobBarDemoView: View {
    @State private var spacing: Double = 3
    @State private var radius: Double = 10
    @State private var threshold: Double = 0.16
    @State private var taps = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LiquidBlobBar").font(.largeTitle.bold())
                        Text("Static fusion · caller-owned surfaces · no injected material")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LIVE PREVIEW").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack {
                            Spacer(minLength: 0)
                            LiquidBlobBar(spacing: spacing, fusionRadius: radius, fusionStrength: 0.9, fusionThreshold: Float(threshold)) {
                                Text(taps == 0 ? "Tap me" : "Tapped \(taps)x")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .frame(height: 48)
                                    .background(Color.indigo, in: Capsule())
                                    .onTapGesture { taps += 1 }
                                Button { taps += 1 } label: {
                                    Image(systemName: "plus").font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white).frame(width: 48, height: 48)
                                        .background(Color.indigo, in: Circle())
                                }.buttonStyle(.plain)
                                Button { taps += 1 } label: {
                                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white).frame(width: 48, height: 48)
                                        .background(Color.indigo, in: Circle())
                                }.buttonStyle(.plain)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        sliderRow("Spacing", value: $spacing, range: 0...20, format: "%.0f pt")
                        sliderRow("Fusion radius", value: $radius, range: 1...18, format: "%.0f pt")
                        sliderRow("Fusion threshold", value: $threshold, range: 0.03...0.45, format: "%.2f")
                    }
                    Text("The sharp foreground remains interactive. Change the gap to see when adjacent surfaces start to bridge. LiquidBlobBar adds no default background or material.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
