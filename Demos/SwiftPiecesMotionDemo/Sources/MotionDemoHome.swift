import SwiftUI

enum MotionDemoItem: String, CaseIterable, Identifiable, Hashable {
    case flipCard, parallaxCard, textReveal, statusMorph, dragToDismiss, depthCarousel, silk

    var id: String { rawValue }
    var title: String {
        switch self {
        case .flipCard: "Flip Card"
        case .parallaxCard: "Parallax Card"
        case .textReveal: "Text Reveal"
        case .statusMorph: "Status Morph"
        case .dragToDismiss: "Drag to Dismiss"
        case .depthCarousel: "Depth Carousel"
        case .silk: "Silk"
        }
    }
    var subtitle: String {
        switch self {
        case .flipCard: "Tap or drag to turn a two-sided card"
        case .parallaxCard: "Layered artwork and a lifting caption"
        case .textReveal: "Staggered text entrance with replay controls"
        case .statusMorph: "One stroke morphs between task states"
        case .dragToDismiss: "Pull a presentation away, then restore it"
        case .depthCarousel: "Paged cards recede around the focused page"
        case .silk: "Animated fabric shading rendered with Metal"
        }
    }
    var symbol: String {
        switch self {
        case .flipCard: "rectangle.on.rectangle.angled"
        case .parallaxCard: "square.3.layers.3d"
        case .textReveal: "text.line.first.and.arrowtriangle.forward"
        case .statusMorph: "circle.lefthalf.filled"
        case .dragToDismiss: "arrow.down.right.and.arrow.up.left"
        case .depthCarousel: "rectangle.3.group"
        case .silk: "water.waves"
        }
    }
    var accent: Color {
        switch self {
        case .flipCard: Color(red: 0.93, green: 0.30, blue: 0.30)
        case .parallaxCard: Color(red: 0.39, green: 0.48, blue: 0.84)
        case .textReveal: Color(red: 0.68, green: 0.40, blue: 0.78)
        case .statusMorph: Color(red: 0.25, green: 0.62, blue: 0.45)
        case .dragToDismiss: Color(red: 0.87, green: 0.49, blue: 0.26)
        case .depthCarousel: Color(red: 0.20, green: 0.60, blue: 0.66)
        case .silk: Color(red: 0.91, green: 0.29, blue: 0.35)
        }
    }
}

struct MotionDemoHome: View {
    @State private var path: [MotionDemoItem] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MOTION STUDIES")
                            .font(.caption.weight(.bold))
                            .tracking(2.2)
                            .foregroundStyle(Color(red: 0.82, green: 0.25, blue: 0.28))
                        Text("SwiftPieces\nMotion Playground")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-1.1)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Seven native motion components. Open one, play with the gesture, and compare how it feels.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(MotionDemoItem.allCases) { item in
                            NavigationLink(value: item) {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(item.accent)
                                            .frame(width: 48, height: 48)
                                            .background(item.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(15)
                                .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.black.opacity(0.045), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("demo.row.\(item.rawValue)")
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                        Text("Tip: try slow drags as well as quick flicks.")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 18)
            }
            .background(Color(red: 0.965, green: 0.953, blue: 0.929).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MotionDemoItem.self) { item in
                MotionDemoDetail(item: item)
            }
        }
        .tint(Color(red: 0.84, green: 0.25, blue: 0.29))
    }
}

struct MotionDemoDetail: View {
    let item: MotionDemoItem

    var body: some View {
        Group {
            switch item {
            case .flipCard: FlipCardDemoScreen()
            case .parallaxCard: ParallaxCardDemoScreen()
            case .textReveal: TextRevealDemoScreen()
            case .statusMorph: StatusMorphDemoScreen()
            case .dragToDismiss: DragToDismissDemoScreen()
            case .depthCarousel: DepthCarouselDemoScreen()
            case .silk: SilkDemoScreen()
            }
        }
        .background(Color(red: 0.965, green: 0.953, blue: 0.929).ignoresSafeArea())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.965, green: 0.953, blue: 0.929), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
