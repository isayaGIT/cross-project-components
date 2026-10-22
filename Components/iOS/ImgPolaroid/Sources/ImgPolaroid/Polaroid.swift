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
    @State private var gestureStartRotation: Double = 0
    @State private var cardCenterInGlobal = CGPoint.zero
    @State private var rotationStartTouch = CGPoint.zero
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
            .overlay(alignment: .topLeading) {
                if isDraggable { rotationHitTarget(direction: .leftCorner) }
            }
            .overlay(alignment: .topTrailing) {
                if isDraggable { rotationHitTarget(direction: .rightCorner) }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(longPressGesture)
            .gesture(isDraggable ? moveGesture : nil)
            .rotationEffect(.degrees(displayedRotation))
            .scaleEffect(isRaised || isDragging ? 1.035 : 1)
            .offset(x: position.width + dragTranslation.width, y: position.height + dragTranslation.height)
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
    }

    /// A real, invisible hit target that rotates with the card. Rotation no longer
    /// depends on classifying a global touch point against a reconstructed card frame.
    /// Both corners share the same polar-angle calculation. Mirroring the horizontal
    /// axis lets one direction parameter express their opposite rotation directions.
    private func rotationHitTarget(direction: PolaroidRotationDirection) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: cornerHitSize, height: cornerHitSize)
            .contentShape(Rectangle())
            .highPriorityGesture(rotationGesture(direction: direction))
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

    private func rotationGesture(direction: PolaroidRotationDirection) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !rotationGestureStarted {
                    rotationGestureStarted = true
                    gestureStartRotation = displayedRotation
                    rotationStartTouch = value.startLocation
                    longPressRecognized = false
                    isDragging = true
                    onDragStateChange?(true)
                }
                let angle = PolaroidRotationMath.angle(
                    startingAt: gestureStartRotation,
                    startPoint: rotationStartTouch,
                    currentPoint: value.location,
                    center: cardCenterInGlobal,
                    direction: direction
                )
                setRotation(angle)
                onRotationChange?(angle)
            }
            .onEnded { _ in
                rotationGestureStarted = false
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

/// The two handles share one rotation algorithm but mirror its horizontal reference axis.
enum PolaroidRotationDirection: Double {
    case leftCorner = -1
    case rightCorner = 1
}

/// Converts the finger's angular movement around the card center into card rotation.
enum PolaroidRotationMath {
    static func angle(
        startingAt start: Double,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        center: CGPoint,
        direction: PolaroidRotationDirection
    ) -> Double {
        let startAngle = polarAngle(point: startPoint, center: center)
        let currentAngle = polarAngle(point: currentPoint, center: center)
        let rawDelta = currentAngle - startAngle
        let delta = atan2(sin(rawDelta), cos(rawDelta))
        return start + delta * direction.rawValue * 180 / .pi
    }

    private static func polarAngle(point: CGPoint, center: CGPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x)
    }
}
