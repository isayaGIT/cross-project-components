import SwiftUI
import Animated
import ImgView

@main
struct AnimatedShowcaseApp: App {
    var body: some Scene {
        WindowGroup { AnimatedShowcase() }
    }
}

private struct AnimatedShowcase: View {
    @State private var showDragToDismiss = false
    @State private var pressScale: Double = 0.94
    @State private var pressDuration: Double = 0.12
    @State private var popSpeed: Double = 1.0

    private let popInImage = ImgViewImage(
        id: "pop-in-landscape",
        url: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?fm=jpg&fit=max&w=6000&q=90")!,
        previewURL: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=max&w=480&q=35")!
    )

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Animated").font(.largeTitle.bold())
                        Text("Two independent interaction experiments").font(.subheadline).foregroundStyle(.secondary)
                    }

                    sectionHeader("01", title: "CoverFlow One", subtitle: "Drag horizontally, flick to throw, or use the arrows. The center card snaps into focus.")
                    VStack(spacing: 14) {
                        CoverFlowCarousel(
                            slides: coverFlowSlides,
                            cardWidth: 158,
                            showsCaption: true,
                            showsPagination: true,
                            showsNavigation: true
                        )
                        .padding(.vertical, 8)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))

                    sectionHeader("02", title: "PressedDown", subtitle: "Press and hold the card. Release to spring back.")
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

                    sectionHeader("03", title: "ImgView + PopIn", subtitle: "Tap the photo. ImgView opens from that thumbnail; transition wiring lives inside the reusable link component.")
                    VStack(spacing: 16) {
                        ImgViewPopInLink(
                            images: [popInImage],
                            speed: popSpeed,
                            sourceCornerRadius: 22,
                            destinationCornerRadius: 0
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                AsyncImage(url: popInImage.previewURL) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle().fill(.quaternary).overlay(ProgressView())
                                    }
                                }
                                .frame(height: 190)
                                .frame(maxWidth: .infinity)
                                .clipped()

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Open image viewer").font(.headline)
                                        Text("Zoom · Pan · Swipe to dismiss").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                            }
                            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        VStack(spacing: 14) {
                            parameterSlider("Speed", value: $popSpeed, range: 0.5...2.5, valueText: String(format: "%.1f×", popSpeed))
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))

                    sectionHeader("04", title: "DragToDismiss", subtitle: "Drag the photo in any direction. Let go early to spring back, or flick to dismiss.")
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

    }

    private var coverFlowSlides: [CoverFlowSlide] {
        let items: [(String, String, String, Color)] = [
            ("sun.max.fill", "Tidewater", "Long Player", .orange),
            ("moon.stars.fill", "Nightshift", "Long Player", .indigo),
            ("sparkles", "Overexposed", "Single", .pink),
            ("bird.fill", "Slow Bloom", "EP", .teal),
            ("hand.raised.fill", "Open Palm", "Single", .purple),
            ("leaf.fill", "Low Country", "Long Player", .green),
            ("sun.horizon.fill", "Dry Season", "EP", .yellow),
            ("tree.fill", "Understory", "Single", .mint),
            ("cloud.fog.fill", "Paper Lantern", "Single", .cyan),
            ("water.waves", "Still Water", "Long Player", .blue),
            ("bolt.fill", "Third Rail", "EP", .red),
            ("snowflake", "Undertow", "Single", .gray)
        ]
        return items.map { item in
            CoverFlowSlide(
                id: item.1,
                image: Image(systemName: item.0).renderingMode(.template),
                accessibilityLabel: item.1,
                title: item.1,
                subtitle: item.2,
                metadata: [(label: "Collection", value: "CoverFlow Demo")]
            )
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
