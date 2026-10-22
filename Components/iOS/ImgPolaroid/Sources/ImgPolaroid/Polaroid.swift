import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A single interactive instant-photo card.
/// The host owns image loading and persistence; this view handles gestures and presentation.
public struct Polaroid: View {
    public let image: Image?
    public let caption: String
    public var width: CGFloat
    private var rotationBinding: Binding<Double>?
    public var isDraggable: Bool
    public var showsShadow: Bool
    public var onTap: (() -> Void)?
    public var onDragStateChange: ((Bool) -> Void)?
    public var onRotationChange: ((Double) -> Void)?
    private var positionBinding: Binding<CGSize>?
    private var isRaisedBinding: Binding<Bool>?

    @State private var localPosition: CGSize = .zero
    @State private var localIsRaised = false
    @State private var localRotation: Double = 0
    @State private var dragTranslation: CGSize = .zero
    @State private var dragStartPosition: CGSize = .zero
    @State private var cardCenterInGlobal = CGPoint.zero
    @State private var rotationPivotCenter = CGPoint.zero
    @State private var previousRotationPointerAngle: Double?
    @State private var isDragging = false
    @State private var moveGestureStarted = false
    @State private var rotationGestureStarted = false
    @State private var longPressRecognized = false

    private let dragThreshold: CGFloat = 3
    private let cornerHitSize: CGFloat = 48
    private let bottomCaptionHeight: CGFloat = 42

    public init(
        image: Image?,
        caption: String = "",
        width: CGFloat = 156,
        rotation: Binding<Double>? = nil,
        position: Binding<CGSize>? = nil,
        isRaised: Binding<Bool>? = nil,
        isDraggable: Bool = true,
        showsShadow: Bool = true,
        onTap: (() -> Void)? = nil,
        onDragStateChange: ((Bool) -> Void)? = nil,
        onRotationChange: ((Double) -> Void)? = nil
    ) {
        self.image = image
        self.caption = caption
        self.width = max(72, width)
        self.rotationBinding = rotation
        self._localRotation = State(initialValue: rotation?.wrappedValue ?? 0)
        self.positionBinding = position
        self.isRaisedBinding = isRaised
        self.isDraggable = isDraggable
        self.showsShadow = showsShadow
        self.onTap = onTap
        self.onDragStateChange = onDragStateChange
        self.onRotationChange = onRotationChange
    }

    private var imageSide: CGFloat { width - 20 }
    private var cardHeight: CGFloat { imageSide + bottomCaptionHeight + 20 }
    private var displayedRotation: Double { rotationBinding?.wrappedValue ?? localRotation }
    private var position: CGSize { positionBinding?.wrappedValue ?? localPosition }
    private var isRaised: Bool { isRaisedBinding?.wrappedValue ?? localIsRaised }

    private func setPosition(_ value: CGSize) {
        if let positionBinding { positionBinding.wrappedValue = value }
        else { localPosition = value }
    }

    private func setRaised(_ value: Bool) {
        if let isRaisedBinding { isRaisedBinding.wrappedValue = value }
        else { localIsRaised = value }
    }

    private func setRotation(_ value: Double) {
        // Direct manipulation must not be interpolated by an implicit animation.
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if let rotationBinding { rotationBinding.wrappedValue = value }
            else { localRotation = value }
        }
    }

    public var body: some View {
        card
            .frame(width: width, height: cardHeight)
            .overlay(alignment: .topLeading) {
                if isDraggable { rotationHitTarget(isLeading: true) }
            }
            .overlay(alignment: .topTrailing) {
                if isDraggable { rotationHitTarget(isLeading: false) }
            }
            .contentShape(Rectangle())
            .rotationEffect(.degrees(displayedRotation))
            // Keep the rotation geometry rigid: scaling during a corner drag would
            // move the corner away from the finger while the angle is being updated.
            .scaleEffect(!rotationGestureStarted && (isRaised || isDragging) ? 1.035 : 1)
            .offset(x: position.width + dragTranslation.width, y: position.height + dragTranslation.height)
            .background {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    Color.clear.preference(
                        key: PolaroidGlobalCenterPreferenceKey.self,
                        value: CGPoint(x: frame.midX, y: frame.midY)
                    )
                }
            }
            .onPreferenceChange(PolaroidGlobalCenterPreferenceKey.self) { cardCenterInGlobal = $0 }
            .shadow(
                color: .black.opacity(showsShadow ? (isRaised || isDragging ? 0.22 : 0.12) : 0),
                radius: isDragging ? 18 : (isRaised ? 13 : 6),
                x: 0,
                y: isDragging ? 11 : (isRaised ? 8 : 3)
            )
            .zIndex(isDragging || isRaised ? 10 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isRaised)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(caption.isEmpty ? "Photo" : caption)
            .accessibilityHint(isDraggable ? "Long press to select, drag to move, or drag a top corner to rotate" : "")
    }

    private var card: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(red: 0.94, green: 0.93, blue: 0.90)
                if let image {
                    image.resizable().scaledToFill().frame(width: imageSide, height: imageSide).clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: imageSide * 0.22, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .frame(width: imageSide, height: imageSide)
            .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
            .overlay { Rectangle().stroke(Color.black.opacity(0.10), lineWidth: 0.6) }
            .padding(.top, 10)
            .padding(.horizontal, 10)

            Text(caption.isEmpty ? " " : caption)
                .font(.system(size: max(10, width * 0.074), weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.20, green: 0.19, blue: 0.17))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: bottomCaptionHeight, maxHeight: bottomCaptionHeight)
                .padding(.horizontal, 8)
        }
        .background(Color(red: 0.995, green: 0.987, blue: 0.958))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color(red: 0.48, green: 0.43, blue: 0.35).opacity(0.13), lineWidth: 0.65) }
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.58)).frame(height: 0.8).padding(.horizontal, 3) }
        // Movement and long-press live on the card surface, beneath the corner overlays.
        // A corner overlay's high-priority rotation gesture therefore owns that touch.
        .simultaneousGesture(longPressGesture)
        .gesture(isDraggable ? moveGesture : nil)
    }

    /// The hit region starts rotation; the gesture then tracks globally and no longer
    /// depends on the moving corner remaining beneath the original hit region.
    private func rotationHitTarget(isLeading: Bool) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: cornerHitSize, height: cornerHitSize)
            .contentShape(Rectangle())
            .highPriorityGesture(rotationGesture(isLeading: isLeading))
            .accessibilityHidden(true)
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.24, maximumDistance: 10)
            .onEnded { recognized in
                guard recognized else { return }
                longPressRecognized = true
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { setRaised(true) }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                // Corner rotation owns its drag. Do not let the card-surface drag
                // update movement state if SwiftUI also delivers this event here.
                guard !rotationGestureStarted else { return }

                if !moveGestureStarted {
                    moveGestureStarted = true
                    dragStartPosition = position
                    longPressRecognized = false
                }
                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= dragThreshold else { return }

                if !isDragging {
                    isDragging = true
                    onDragStateChange?(true)
                }
                dragTranslation = value.translation
            }
            .onEnded { value in
                // A corner drag must never be committed as a card move or tap.
                guard !rotationGestureStarted else { return }
                let distance = hypot(value.translation.width, value.translation.height)
                if distance >= dragThreshold {
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        setPosition(CGSize(
                            width: dragStartPosition.width + value.translation.width,
                            height: dragStartPosition.height + value.translation.height
                        ))
                        dragTranslation = .zero
                    }
                    setRaised(false)
                } else if !longPressRecognized {
                    dragTranslation = .zero
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.76)) { setRaised(!isRaised) }
                    onTap?()
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                }
                moveGestureStarted = false
                finishDrag()
            }
    }

    private func rotationGesture(isLeading: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                // Accumulate each pointer movement instead of measuring every event
                // against the initial ray. This avoids a fixed-start angle wrap when a
                // continuous drag crosses the polar-angle discontinuity.
                if !rotationGestureStarted {
                    rotationGestureStarted = true
                    rotationPivotCenter = cardCenterInGlobal
                    previousRotationPointerAngle = PolaroidRotationMath.polarAngle(
                        point: value.location,
                        center: rotationPivotCenter
                    )
                    longPressRecognized = false
                    moveGestureStarted = false
                    dragTranslation = .zero
                    isDragging = true
                    onDragStateChange?(true)
                    return
                }

                let pointerAngle = PolaroidRotationMath.polarAngle(
                    point: value.location,
                    center: rotationPivotCenter
                )
                if let previous = previousRotationPointerAngle {
                    let delta = PolaroidRotationMath.shortestAngularDelta(from: previous, to: pointerAngle)
                    // Preserve the established leading/trailing corner direction convention.
                    let angle = displayedRotation + (isLeading ? -delta : delta)
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        setRotation(angle)
                    }
                    onRotationChange?(angle)
                }
                previousRotationPointerAngle = pointerAngle
            }
            .onEnded { _ in
                rotationGestureStarted = false
                previousRotationPointerAngle = nil
                moveGestureStarted = false
                finishDrag()
                setRaised(false)
            }
    }

    private func finishDrag() {
        let wasDragging = isDragging
        isDragging = false
        dragTranslation = .zero
        if wasDragging { onDragStateChange?(false) }
    }
}

private struct PolaroidGlobalCenterPreferenceKey: PreferenceKey {
    static var defaultValue = CGPoint.zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

/// Angle tracking for rotation around the Polaroid card center. The pivot stays fixed;
/// rotating never writes to the card position.
enum PolaroidRotationMath {
    /// Returns the pointer's polar angle around a pivot, in radians.
    static func polarAngle(point: CGPoint, center: CGPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x)
    }

    /// Smallest signed angular difference between consecutive pointer rays.
    /// Accumulating these deltas prevents a fixed-start wrap during long rotations.
    static func shortestAngularDelta(from start: Double, to current: Double) -> Double {
        atan2(sin(current - start), cos(current - start)) * 180 / .pi
    }
}
