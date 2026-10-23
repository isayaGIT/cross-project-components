import SwiftUI
import Animated

@main
struct AnimatedShowcaseApp: App {
    var body: some Scene {
        WindowGroup { AnimatedShowcase() }
    }
}

private struct AnimatedShowcase: View {
    @State private var showPopIn = false
    @State private var showDragToDismiss = false
    @State private var pressScale: Double = 0.94
    @State private var pressDuration: Double = 0.12
    @State private var popSpeed: Double = 1.0

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Animated").font(.largeTitle.bold())
                        Text("Two independent interaction experiments").font(.subheadline).foregroundStyle(.secondary)
                    }

                    sectionHeader("01", title: "PressedDown", subtitle: "Press and hold the card. Release to spring back.")
                    VStack(spacing: 18) {
                        Button {} label: {
                            HStack(spacing: 14) {
                                Image(systemName: "hand.tap.fill").font(.system(size: 27)).frame(width: 58, height: 58).background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Press me").font(.headline)
                                    Text("Only this card has press feedback").font(.caption).opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "arrow.down.right.and.arrow.up.left").font(.title3)
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                        }
                        .buttonStyle(.pressedDown(.init(scale: pressScale, animationDuration: pressDuration)))

                        VStack(spacing: 14) {
                            parameterSlider("Pressed scale", value: $pressScale, range: 0.85...0.99, valueText: String(format: "%.2f", pressScale))
                            parameterSlider("Duration", value: $pressDuration, range: 0.05...0.3, valueText: String(format: "%.2fs", pressDuration))
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))

                    sectionHeader("02", title: "PopIn", subtitle: "Tap the avatar. A complete contact card grows out of that exact spot.")
                    VStack(spacing: 16) {
                        Button { showPopIn = true } label: {
                            HStack(spacing: 14) {
                                Image("PopInPhoto")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .clipShape(Circle())
                                    .popInSource(id: "moment-pop-source")
                                    .opacity(showPopIn ? 0 : 1)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Alex Morgan").font(.headline)
                                    Text("Product designer · Berlin").font(.subheadline).foregroundStyle(.secondary)
                                    Text("Tap to view contact card").font(.caption).foregroundStyle(.indigo)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        VStack(spacing: 14) {
                            parameterSlider("Speed", value: $popSpeed, range: 0.5...2.5, valueText: String(format: "%.1f×", popSpeed))
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))
                    
                    sectionHeader("03", title: "DragToDismiss", subtitle: "Drag the photo in any direction. Let go early to spring back, or flick to dismiss.")
                    Button { showDragToDismiss = true } label: {
                        HStack(spacing: 14) {
                            Image("PopInPhoto")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 74, height: 88)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Open photo viewer").font(.headline)
                                Text("Try the two-axis drag interaction").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.title3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))
                    Text("Each sample is isolated: PressedDown does not trigger PopIn, and PopIn has its own overlay and controls.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .overlay {
            if showDragToDismiss {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image("PopInPhoto")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    VStack {
                        HStack {
                            Text("DRAG TO DISMISS")
                                .font(.caption.bold())
                                .tracking(1.1)
                            Spacer()
                            Image(systemName: "hand.draw")
                        }
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .dragToDismiss(cornerRadius: 28) { showDragToDismiss = false }
                .zIndex(200)
            }
        }
        .popInTransition(
            isPresented: $showPopIn,
            id: "moment-pop-source",
            speed: popSpeed,
            // Use the full available width so the backdrop never forms grey side gutters.
            destinationAspectRatio: nil,
            sourceCornerRadius: 34,
            destinationCornerRadius: 30,
            backdropOpacity: 0.2,
            backdropBlurOpacity: 0.42,
            contentRevealStart: 0.18,
            contentRevealEnd: 0.64
        ) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image("PopInPhoto")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Button { showPopIn = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.38), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close contact card")
                    }
                    .padding(18)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Alex Morgan").font(.title2.bold())
                        Text("Product Designer").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Designing thoughtful digital experiences. Usually found sketching interfaces or exploring a new city.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Label("Berlin", systemImage: "mappin.and.ellipse")
                        Label("12 mutuals", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {} label: {
                            Label("Message", systemImage: "bubble.left.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {} label: {
                            Image(systemName: "phone.fill")
                                .frame(width: 48, height: 42)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    private func sectionHeader(_ number: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(number)  /  \(title.uppercased())").font(.caption.bold()).tracking(1.2).foregroundStyle(.indigo)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func parameterSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title).font(.subheadline); Spacer(); Text(valueText).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary) }
            Slider(value: value, in: range)
        }
    }
}
