import SwiftUI

private struct DemoSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color(red: 0.82, green: 0.25, blue: 0.28))
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                content
            }
            .padding(20)
        }
        .accessibilityIdentifier("demo.screen.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

struct FlipCardDemoScreen: View {
    @State private var isFlipped = false

    var body: some View {
        DemoSection(title: "Flip Card", detail: "Tap the card or drag it sideways. Release commits the turn or lets it spring back.") {
            FlipCard(isFlipped: $isFlipped, style: .init(hint: true)) {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.96, green: 0.42, blue: 0.38), Color(red: 0.78, green: 0.18, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .medium))
                        Text("FRONT")
                            .font(.caption.weight(.bold)).tracking(3)
                        Text("A little wonder")
                            .font(.title2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } back: {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.18, green: 0.24, blue: 0.40), Color(red: 0.31, green: 0.40, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 16) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 38, weight: .medium))
                        Text("BACK")
                            .font(.caption.weight(.bold)).tracking(3)
                        Text("The other side")
                            .font(.title2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .frame(height: 330)
            .accessibilityIdentifier("demo.flip-card")

            HStack {
                Label(isFlipped ? "Back face" : "Front face", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Flip") { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { isFlipped.toggle() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("demo.flip-card.flip")
            }
        }
    }
}

struct ParallaxCardDemoScreen: View {
    @State private var pressCount = 0

    var body: some View {
        DemoSection(title: "Parallax Card", detail: "The artwork and caption travel at different rates. Press the card to lift it and lean the action bubble.") {
            ParallaxCard(
                image: Image(systemName: "mountain.2.fill"),
                eyebrow: "FIELD NOTES · 07",
                title: "Somewhere quiet",
                metadata: ["Alpine light", "6 min read"],
                trailingSymbol: "arrow.up.right",
                height: 300,
                parallax: 0.34,
                style: .scrim,
                action: { pressCount += 1 }
            )
            .accessibilityIdentifier("demo.parallax-card")

            HStack {
                Text("Presses registered")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pressCount)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .accessibilityIdentifier("demo.parallax-count")
            }
            .font(.subheadline)
        }
    }
}

struct TextRevealDemoScreen: View {
    @State private var replay = 0
    @State private var unit = 1
    @State private var preset = 0

    private var chosenUnit: TextReveal.Unit { [.characters, .words, .lines][unit] }
    private var chosenPreset: TextReveal.Preset { [.rise, .blur, .soften][preset] }
    private let sample = "Good things take the time they need."

    var body: some View {
        DemoSection(title: "Text Reveal", detail: "Choose how text is segmented and how each piece arrives, then replay the entrance.") {
            VStack(alignment: .leading, spacing: 18) {
                TextReveal(sample, unit: chosenUnit, preset: chosenPreset, duration: 0.95, trigger: replay, highlights: ["time", "need"])
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityIdentifier("demo.text-reveal")

                VStack(alignment: .leading, spacing: 10) {
                    Text("SEGMENT")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                    Picker("Segment", selection: $unit) {
                        Text("Characters").tag(0)
                        Text("Words").tag(1)
                        Text("Lines").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("demo.text-reveal.unit")

                    Text("PRESET")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                    Picker("Preset", selection: $preset) {
                        Text("Rise").tag(0)
                        Text("Blur").tag(1)
                        Text("Soften").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("demo.text-reveal.preset")
                }

                Button {
                    replay += 1
                } label: {
                    Label("Replay entrance", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("demo.text-reveal.replay")
            }
            .onChange(of: unit) { _, _ in replay += 1 }
            .onChange(of: preset) { _, _ in replay += 1 }
        }
    }
}

struct StatusMorphDemoScreen: View {
    @State private var state: StatusMorph.State = .loading

    var body: some View {
        DemoSection(title: "Status Morph", detail: "The same stroke spins, closes, floods into a block, then draws a check or cross.") {
            VStack(spacing: 28) {
                VStack(spacing: 18) {
                    StatusMorph(state: state, captions: .init(idle: "Ready", loading: "Working", success: "Completed", failure: "Needs attention"), size: 108, lineWidth: 7)
                        .frame(height: 160)
                        .accessibilityIdentifier("demo.status-morph")
                    Text(stateLabel)
                        .font(.headline)
                        .accessibilityIdentifier("demo.status-morph.label")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("SET STATE")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        statusButton("Idle", state: .idle, symbol: "circle")
                        statusButton("Loading", state: .loading, symbol: "arrow.triangle.2.circlepath")
                        statusButton("Success", state: .success, symbol: "checkmark")
                        statusButton("Failure", state: .failure, symbol: "xmark")
                    }
                }
            }
        }
    }

    private var stateLabel: String {
        switch state {
        case .idle: "Idle"
        case .loading: "Loading"
        case .success: "Success"
        case .failure: "Failure"
        }
    }

    private func statusButton(_ title: String, state value: StatusMorph.State, symbol: String) -> some View {
        Button {
            state = value
        } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.headline)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(state == value ? .white : .primary)
            .background(state == value ? Color(red: 0.82, green: 0.25, blue: 0.28) : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("demo.status-morph.\(title.lowercased())")
    }
}

struct DragToDismissDemoScreen: View {
    @State private var isPresented = true
    @State private var dismissCount = 0

    var body: some View {
        DemoSection(title: "Drag to Dismiss", detail: "Drag the surface far enough or flick it away. The sample can be restored without leaving this screen.") {
            VStack(spacing: 18) {
                if isPresented {
                    VStack(spacing: 18) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Hold. Pull. Let go.")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("This surface is the gesture target.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Label("Drag in any direction", systemImage: "hand.draw")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .background(LinearGradient(colors: [Color(red: 0.19, green: 0.23, blue: 0.36), Color(red: 0.38, green: 0.43, blue: 0.59)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityIdentifier("demo.drag-dismiss.surface")
                    .dragToDismiss(threshold: 105, onDismiss: {
                        dismissCount += 1
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { isPresented = false }
                    })
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                        Text("Dismissed").font(.title2.weight(.bold))
                        Text("The dismiss callback fired. Restore to try again.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityIdentifier("demo.drag-dismiss.dismissed")
                }

                HStack {
                    Label("Dismiss callbacks", systemImage: "arrowshape.turn.up.right")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(dismissCount)").font(.headline.monospacedDigit())
                        .accessibilityIdentifier("demo.drag-dismiss.count")
                }
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { isPresented = true }
                } label: {
                    Label("Restore sample", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("demo.drag-dismiss.restore")
            }
        }
    }
}

private struct CarouselSample: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
}

struct DepthCarouselDemoScreen: View {
    @State private var selection: Int? = 1
    private let samples: [CarouselSample] = [
        .init(id: 0, title: "Dawn", subtitle: "A new beginning", symbol: "sunrise.fill", colors: [Color(red: 0.97, green: 0.62, blue: 0.44), Color(red: 0.85, green: 0.34, blue: 0.40)]),
        .init(id: 1, title: "Stillness", subtitle: "A slower kind of day", symbol: "water.waves", colors: [Color(red: 0.27, green: 0.62, blue: 0.69), Color(red: 0.16, green: 0.39, blue: 0.55)]),
        .init(id: 2, title: "Afterglow", subtitle: "Keep the last light", symbol: "moon.stars.fill", colors: [Color(red: 0.45, green: 0.40, blue: 0.70), Color(red: 0.22, green: 0.25, blue: 0.48)]),
        .init(id: 3, title: "Meadow", subtitle: "A quiet patch of green", symbol: "leaf.fill", colors: [Color(red: 0.51, green: 0.70, blue: 0.47), Color(red: 0.23, green: 0.47, blue: 0.36)])
    ]

    var body: some View {
        DemoSection(title: "Depth Carousel", detail: "Swipe between pages, tap a neighbor to bring it forward, or use the native scrubbable indicator.") {
            DepthCarousel(samples, itemWidth: 286, spacing: 14, selection: $selection) { sample, phase in
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: sample.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.14)).frame(width: 180).offset(x: 145 + phase * 16, y: -135)
                    Image(systemName: sample.symbol)
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(x: phase * 22, y: -110)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sample.title).font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(sample.subtitle).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityIdentifier("demo.depth-carousel.page.\(sample.id)")
            }
            .frame(height: 430)
            .accessibilityIdentifier("demo.depth-carousel")

            HStack {
                Text("SELECTED PAGE")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                Text("\((selection ?? 0) + 1) / \(samples.count)")
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("demo.depth-carousel.selection")
            }
        }
    }
}

struct SilkDemoScreen: View {
    @State private var tint = 0
    @State private var tiltLight = false
    @State private var isPaused = false
    private let styles: [Silk.Style] = [.standard, .tangerine, .lilac, .sage, .indigo]
    private let names = ["Adaptive", "Signal", "Lilac", "Sage", "Indigo"]

    var body: some View {
        DemoSection(title: "Silk", detail: "A live Metal shader builds a folded fabric surface. Change its palette, pause its motion, or enable tilt-driven lighting.") {
            ZStack(alignment: .bottomLeading) {
                Silk(style: styles[tint], tiltLight: tiltLight, speed: isPaused ? 0 : 1)
                    .accessibilityIdentifier("demo.silk.shader")
                VStack(alignment: .leading, spacing: 12) {
                    Text("SOFT STRUCTURE")
                        .font(.caption.weight(.bold)).tracking(2)
                        .foregroundStyle(.white.opacity(0.76))
                    Text("Light finds\nits own way.")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A surface made of motion.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(24)
            }
            .frame(height: 390)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .accessibilityIdentifier("demo.silk.preview")

            VStack(alignment: .leading, spacing: 12) {
                Text("FABRIC")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(names.indices, id: \.self) { index in
                            Button(names[index]) { tint = index }
                                .buttonStyle(.borderedProminent)
                                .tint(tint == index ? Color(red: 0.82, green: 0.25, blue: 0.28) : .gray.opacity(0.22))
                                .foregroundStyle(tint == index ? .white : .primary)
                                .accessibilityIdentifier("demo.silk.tint.\(index)")
                        }
                    }
                }
                Toggle("Tilt light with device", isOn: $tiltLight)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("demo.silk.tilt")
                Toggle("Pause fabric animation", isOn: $isPaused)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("demo.silk.pause")
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
