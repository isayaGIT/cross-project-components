import SwiftUI
import QuartzCore

/// Native SwiftUI adaptation of Ruixen UI's Coverflow Carousel.
/// The layout follows the source's fractional `pos`, eased distance ramp,
/// reversed Y rotation, Z recession, fading seam and exponential settle.
public struct CoverFlowSlide: Identifiable, Hashable {
    public let id: String
    public let image: Image
    public let accessibilityLabel: String
    public var title: String?
    public var subtitle: String?
    public var metadata: [(label: String, value: String)]

    public init(
        id: String,
        image: Image,
        accessibilityLabel: String,
        title: String? = nil,
        subtitle: String? = nil,
        metadata: [(label: String, value: String)] = []
    ) {
        self.id = id
        self.image = image
        self.accessibilityLabel = accessibilityLabel
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct CoverFlowCarousel: View {
    public let slides: [CoverFlowSlide]
    public var rotate: Double
    public var depth: Double
    public var perspective: Double
    public var falloff: Double
    public var fade: Double
    public var cardWidth: CGFloat
    public var gap: Double
    public var loops: Bool
    public var showsCaption: Bool
    public var showsPagination: Bool
    public var showsNavigation: Bool
    public var accessibilityLabel: String

    @State private var position: Double = 0
    @State private var targetPosition: Double = 0
    @State private var selectedIndex: Int = 0
    @State private var dragStartPosition: Double?
    @State private var dragStartTranslation: CGFloat = 0
    @State private var lastDragTranslation: CGFloat = 0
    @State private var dragVelocity: Double = 0
    @State private var lastDragTime: Date = .now

    public init(
        slides: [CoverFlowSlide],
        rotate: Double = 44,
        depth: Double = 0.6,
        perspective: Double = 3,
        falloff: Double = 0.56,
        fade: Double = 0.1,
        cardWidth: CGFloat = 220,
        gap: Double = 0.05,
        loops: Bool = true,
        showsCaption: Bool = false,
        showsPagination: Bool = false,
        showsNavigation: Bool = false,
        accessibilityLabel: String = "Cover carousel"
    ) {
        self.slides = slides
        self.rotate = rotate
        self.depth = depth
        self.perspective = perspective
        self.falloff = falloff
        self.fade = fade
        self.cardWidth = cardWidth
        self.gap = gap
        self.loops = loops
        self.showsCaption = showsCaption
        self.showsPagination = showsPagination
        self.showsNavigation = showsNavigation
        self.accessibilityLabel = accessibilityLabel
    }

    private var count: Int { slides.count }
    private var activeSlide: CoverFlowSlide? {
        guard slides.indices.contains(selectedIndex) else { return nil }
        return slides[selectedIndex]
    }
    private var pitch: CGFloat { cardWidth * (1 + gap) }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                GeometryReader { proxy in
                    ZStack {
                        ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                            card(slide, index: index)
                        }
                    }
                    .frame(width: proxy.size.width, height: cardWidth)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(accessibilityLabel)
                    .focusable()
                    .onKeyPress(.leftArrow) { step(-1); return .handled }
                    .onKeyPress(.rightArrow) { step(1); return .handled }
                }
                .frame(height: cardWidth + 44)
                .clipped()

                if showsNavigation {
                    HStack {
                        navigationButton(systemName: "chevron.left", action: { step(-1) })
                        Spacer()
                        navigationButton(systemName: "chevron.right", action: { step(1) })
                    }
                    .padding(.horizontal, 10)
                }
            }

            if showsCaption, let slide = activeSlide, let title = slide.title {
                VStack(spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    if let subtitle = slide.subtitle {
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    if !slide.metadata.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(slide.metadata.enumerated()), id: \.offset) { _, item in
                                HStack {
                                    Text(item.label).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(item.value).fontWeight(.medium)
                                }
                                .font(.system(size: 12))
                                .padding(.vertical, 5)
                            }
                        }
                        .frame(maxWidth: 230)
                        .padding(.top, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
                .id(selectedIndex)
            }

            if showsPagination {
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { index in
                        Button { goTo(index) } label: {
                            Circle()
                                .fill(Color.primary.opacity(index == selectedIndex ? 1 : 0.3))
                                .frame(width: 8, height: 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to slide \(index + 1)")
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                    }
                }
                .padding(.top, 16)
            }
        }
        .onChange(of: slides.count) { _, newCount in
            guard newCount > 0 else { position = 0; targetPosition = 0; selectedIndex = 0; return }
            position = min(position, Double(newCount - 1))
            targetPosition = position
            selectedIndex = normalized(Int(position.rounded()))
        }
    }

    private func card(_ slide: CoverFlowSlide, index: Int) -> some View {
        let offset = offsetFor(index)
        let distance = abs(offset)
        let ramp = pow(distance, falloff)
        let tilt = min(rotate * ramp, 82) * (offset < 0 ? -1.0 : 1.0)
        let edge = loops ? min(1, max(0, Double(count) / 2 - distance)) : 1
        let opacity = max(0, 1 - fade * distance) * edge

        // Build a visible extruded edge behind the artwork. The repeated dark
        // layers are intentionally offset toward the receding edge, so rotation
        // reveals a real, solid side instead of relying on a drop shadow.
        let thickness: CGFloat = 9
        let extrusionDirection: CGFloat = tilt >= 0 ? 1 : -1
        let sideColor = Color(red: 0.19, green: 0.18, blue: 0.17)
        let artwork = slide.image
            .resizable()
            .scaledToFill()
            .frame(width: cardWidth, height: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let decorated = ZStack {
            // Multiple closely spaced layers create a continuous side wall.
            ForEach(0..<9, id: \.self) { layer in
                cardShape
                    .fill(sideColor.opacity(0.72 + Double(layer) * 0.025))
                    .overlay(cardShape.strokeBorder(Color.black.opacity(0.18), lineWidth: 0.35))
                    .offset(x: extrusionDirection * CGFloat(layer + 1))
            }
            // A narrow, brighter bevel makes the physical edge legible.
            HStack(spacing: 0) {
                if extrusionDirection < 0 {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.22)).frame(width: 2)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.22)).frame(width: 2)
                }
            }
            .frame(width: cardWidth, height: cardWidth - 8)
            .padding(.vertical, 4)
            artwork
                .overlay(cardShape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6))
        }
        .frame(width: cardWidth + thickness, height: cardWidth)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 5)
        return decorated
            .rotation3DEffect(.degrees(-tilt), axis: (x: 0, y: 1, z: 0), perspective: 1 / max(perspective, 0.1))
            .scaleEffect(max(0.72, 1 - depth * ramp * 0.08))
            .offset(x: CGFloat(offset) * pitch)
            .opacity(opacity)
            .zIndex(Double(100 - Int(distance.rounded())))
            .accessibilityLabel(slide.accessibilityLabel)
            .accessibilityAddTraits(.isImage)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = position
                    dragStartTranslation = value.translation.width
                    lastDragTranslation = value.translation.width
                    dragVelocity = 0
                    lastDragTime = .now
                    targetPosition = position
                }
                let translation = value.translation.width - dragStartTranslation
                let now = Date()
                let dt = max(now.timeIntervalSince(lastDragTime), 0.001)
                let previousPosition = position
                position = clamped((dragStartPosition ?? position) - Double(translation / max(pitch, 1)))
                dragVelocity = (position - previousPosition) / dt
                lastDragTranslation = value.translation.width
                lastDragTime = now
                selectedIndex = normalized(Int(position.rounded()))
            }
            .onEnded { _ in
                let carried = min(2, max(-2, dragVelocity * 0.18))
                let next = clamped((position + carried).rounded())
                dragStartPosition = nil
                withAnimation(.easeOut(duration: 0.42)) {
                    position = next
                    targetPosition = next
                    selectedIndex = normalized(Int(next.rounded()))
                }
            }
    }

    private func offsetFor(_ index: Int) -> Double {
        guard count > 0 else { return 0 }
        var offset = Double(index) - position
        if loops {
            offset = offset.truncatingRemainder(dividingBy: Double(count))
            if offset < 0 { offset += Double(count) }
            if offset > Double(count) / 2 { offset -= Double(count) }
        }
        return offset
    }

    private func normalized(_ index: Int) -> Int {
        guard count > 0 else { return 0 }
        if loops { return (index % count + count) % count }
        return min(count - 1, max(0, index))
    }

    private func clamped(_ value: Double) -> Double {
        loops ? value : min(Double(max(count - 1, 0)), max(0, value))
    }

    private func step(_ amount: Int) {
        guard count > 0 else { return }
        let base = targetPosition.rounded()
        settle(clamped(base + Double(amount)))
    }

    private func goTo(_ index: Int) {
        guard count > 0 else { return }
        var destination = Double(index)
        if loops {
            destination += ((targetPosition - destination) / Double(count)).rounded() * Double(count)
        }
        settle(clamped(destination))
    }

    private func settle(_ destination: Double) {
        withAnimation(.easeOut(duration: 0.42)) {
            position = destination
            targetPosition = destination
            selectedIndex = normalized(Int(destination.rounded()))
        }
    }

    private func navigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

