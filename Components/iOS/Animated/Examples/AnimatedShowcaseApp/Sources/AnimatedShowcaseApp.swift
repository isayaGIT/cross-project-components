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

                    sectionHeader("02", title: "PopIn", subtitle: "Tap the image. It expands in place into a separate overlay.")
                    VStack(spacing: 16) {
                        Button { showPopIn = true } label: {
                            GeometryReader { geometry in
                                let imageHeight = geometry.size.height
                                let imageWidth = min(geometry.size.width, imageHeight * (2.0 / 3.0))
                                HStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    Image("PopInPhoto")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: imageWidth, height: imageHeight)
                                        // Measure after centering so the source frame matches
                                        // the visible image, not its uncentered GeometryReader origin.
                                        .popInSource(id: "moment-pop-source")
                                    Spacer(minLength: 0)
                                }
                                .frame(width: geometry.size.width, height: imageHeight)
                            }
                            .frame(height: 230)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .opacity(showPopIn ? 0 : 1)
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
        .popInTransition(isPresented: $showPopIn, id: "moment-pop-source", speed: popSpeed, destinationAspectRatio: 2.0 / 3.0) {
            ZStack {
                Color.black
                Image("PopInPhoto")
                    .resizable()
                    .scaledToFill()
                    // Preserve image proportions while filling the animated rectangle.
                    // A changing rectangle crops during flight instead of stretching pixels.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
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
