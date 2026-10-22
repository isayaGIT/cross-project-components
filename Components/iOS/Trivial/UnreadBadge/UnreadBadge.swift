import SwiftUI

/// A draggable unread-count badge with a sticky, gooey connection and a dismiss explosion.
///
/// Inspired by the interaction in KYCuteView (MIT, Copyright (c) 2015 Qitao Yang).
/// This is a native SwiftUI implementation; it does not depend on the original Objective-C library.
public struct UnreadBadge: View {
    public let count: Int
    public var diameter: CGFloat
    public var color: Color
    public var textColor: Color
    public var font: Font
    /// Higher values make the sticky connection stretch farther before thinning.
    public var viscosity: CGFloat
    /// Drag distance at which the connection breaks and the badge can be dismissed.
    public var breakDistance: CGFloat
    public var onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isDismissed = false
    @State private var isExploding = false
    @State private var explosionProgress: CGFloat = 0

    private var label: String {
        count > 99 ? "99+" : "\(max(0, count))"
    }

    private var distance: CGFloat {
        hypot(dragOffset.width, dragOffset.height)
    }

    private var isConnected: Bool {
        isDragging && distance < breakDistance
    }

    private var canvasExtent: CGFloat {
        max(breakDistance, diameter * 2) + diameter * 2
    }

    public init(
        count: Int,
        diameter: CGFloat = 22,
        color: Color = .red,
        textColor: Color = .white,
        font: Font = .system(size: 12, weight: .semibold, design: .rounded),
        viscosity: CGFloat = 18,
        breakDistance: CGFloat = 88,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.count = count
        self.diameter = diameter
        self.color = color
        self.textColor = textColor
        self.font = font
        self.viscosity = max(1, viscosity)
        self.breakDistance = max(diameter, breakDistance)
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            if !isDismissed {
                if isConnected {
                    stickyShape
                        .fill(color)
                        .frame(width: canvasExtent, height: canvasExtent)
                        .allowsHitTesting(false)
                }

                badgeFace
                    .offset(dragOffset)
                    .scaleEffect(isExploding ? 1.35 : 1)
                    .opacity(isExploding ? 0 : 1)
                    .gesture(dragGesture)
            }

            if isExploding {
                explosion
                    .frame(width: diameter * 2.2, height: diameter * 2.2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            // Keeps the badge's layout size stable while the drag artwork can extend beyond it.
            Color.clear
                .frame(width: 0, height: 0)
        }
        .accessibilityElement()
        .accessibilityLabel("\(count) unread")
        .accessibilityHint("Drag to dismiss")
    }

    private var badgeFace: some View {
        Text(label)
            .font(font)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, count > 9 ? 5 : 0)
            .frame(minWidth: diameter, minHeight: diameter)
            .background(color, in: Capsule())
            .contentShape(Capsule())
    }

    private var stickyShape: Path {
        let extent = canvasExtent
        let origin = CGPoint(x: extent / 2, y: extent / 2)
        let current = CGPoint(x: origin.x + dragOffset.width, y: origin.y + dragOffset.height)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let length = max(0.001, hypot(dx, dy))
        let ux = dx / length
        let uy = dy / length
        let px = -uy
        let py = ux
        let baseRadius = diameter / 2
        let anchorRadius = max(2, baseRadius - length / viscosity)
        let movingRadius = baseRadius

        let a = CGPoint(x: origin.x + px * anchorRadius, y: origin.y + py * anchorRadius)
        let b = CGPoint(x: origin.x - px * anchorRadius, y: origin.y - py * anchorRadius)
        let c = CGPoint(x: current.x - px * movingRadius, y: current.y - py * movingRadius)
        let d = CGPoint(x: current.x + px * movingRadius, y: current.y + py * movingRadius)
        let midpoint = CGPoint(x: (origin.x + current.x) / 2, y: (origin.y + current.y) / 2)
        let curveReach = min(length * 0.28, baseRadius * 1.6)
        let controlA = CGPoint(x: midpoint.x - py * curveReach, y: midpoint.y + px * curveReach)
        let controlB = CGPoint(x: midpoint.x + py * curveReach, y: midpoint.y - px * curveReach)

        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: d, control: controlA)
        path.addLine(to: c)
        path.addQuadCurve(to: b, control: controlB)
        path.closeSubpath()
        return path
    }

    private var explosion: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.9))
                    .frame(width: max(2, diameter * 0.16), height: max(2, diameter * 0.16))
                    .offset(x: CGFloat(cos(Double(index) * .pi / 4)) * diameter * 0.72 * explosionProgress,
                            y: CGFloat(sin(Double(index) * .pi / 4)) * diameter * 0.72 * explosionProgress)
                    .scaleEffect(max(0.12, 1 - explosionProgress))
                    .opacity(1 - explosionProgress)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                guard !isDismissed else { return }
                if !isDragging {
                    isDragging = true
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isDismissed else { return }
                let finalDistance = hypot(value.translation.width, value.translation.height)
                if finalDistance >= breakDistance {
                    dismissWithExplosion()
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 240, damping: 13)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
            }
    }

    private func dismissWithExplosion() {
        isDragging = false
        isExploding = true
        withAnimation(.easeOut(duration: 0.22)) {
            isDismissed = true
            explosionProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            onDismiss()
        }
    }
}
