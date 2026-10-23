import SwiftUI

private let popInCoordinateSpaceName = "Animated.PopIn.Root"

private struct PopInSourceFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// Marks the exact visible rectangle that PopIn expands from.
public struct PopInSource: ViewModifier {
    let id: String

    public func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PopInSourceFramesKey.self,
                    value: [id: proxy.frame(in: .named(popInCoordinateSpaceName))]
                )
            }
        }
    }
}

/// Reveals a destination between a measured source rect and a target rect.
/// The geometry, card content, and backdrop share one reversible animation progress.
public struct PopInTransition<Destination: View>: ViewModifier {
    @Binding private var isPresented: Bool
    private let speed: Double
    private let transitionID: String
    private let destinationAspectRatio: CGFloat?
    private let sourceCornerRadius: CGFloat
    private let destinationCornerRadius: CGFloat
    private let backdropOpacity: Double
    private let backdropBlurOpacity: Double
    private let contentRevealStart: CGFloat
    private let contentRevealEnd: CGFloat
    private let destination: Destination

    @State private var sourceFrames: [String: CGRect] = [:]
    @State private var progress: CGFloat = 0
    @State private var isClosing = false
    @State private var isOverlayVisible = false
    @State private var activeDuration = 0.38

    public init(
        isPresented: Binding<Bool>,
        id: String,
        speed: Double = 1,
        destinationAspectRatio: CGFloat? = nil,
        sourceCornerRadius: CGFloat = 22,
        destinationCornerRadius: CGFloat = 0,
        backdropOpacity: Double = 0.14,
        backdropBlurOpacity: Double = 0.24,
        contentRevealStart: CGFloat = 0.24,
        contentRevealEnd: CGFloat = 0.68,
        @ViewBuilder destination: () -> Destination
    ) {
        self._isPresented = isPresented
        self.transitionID = id
        self.speed = max(0.1, speed)
        self.destinationAspectRatio = destinationAspectRatio.flatMap { $0 > 0 ? $0 : nil }
        self.sourceCornerRadius = max(0, sourceCornerRadius)
        self.destinationCornerRadius = max(0, destinationCornerRadius)
        self.backdropOpacity = min(max(backdropOpacity, 0), 1)
        self.backdropBlurOpacity = min(max(backdropBlurOpacity, 0), 1)
        let revealStart = min(max(contentRevealStart, 0), 0.95)
        self.contentRevealStart = revealStart
        self.contentRevealEnd = min(max(contentRevealEnd, revealStart + 0.01), 1)
        self.destination = destination()
    }

    public func body(content: Content) -> some View {
        content
            .onPreferenceChange(PopInSourceFramesKey.self) { sourceFrames = $0 }
            .overlay {
                if isOverlayVisible, let sourceRect = sourceFrames[transitionID] {
                    GeometryReader { proxy in
                        let bounds = CGRect(origin: .zero, size: proxy.size)
                        let overlayFrame = proxy.frame(in: .named(popInCoordinateSpaceName))
                        let localSourceRect = sourceRect.offsetBy(dx: -overlayFrame.minX, dy: -overlayFrame.minY)
                        let targetRect = destinationAspectRatio.map {
                            aspectFitRect(in: bounds, aspectRatio: $0)
                        } ?? bounds
                        let currentRect = interpolatePopInRect(from: localSourceRect, to: targetRect, progress: progress)
                        let clampedProgress = min(max(progress, 0), 1)
                        let cornerRadius = sourceCornerRadius
                            + (destinationCornerRadius - sourceCornerRadius) * clampedProgress
                        let contentProgress = smoothStep(
                            from: contentRevealStart,
                            to: contentRevealEnd,
                            value: clampedProgress
                        )

                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(backdropBlurOpacity * clampedProgress)
                                .overlay { Color.black.opacity(backdropOpacity * clampedProgress) }
                                .contentShape(Rectangle())
                                .onTapGesture { dismiss() }
                                .accessibilityHidden(true)

                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.regularMaterial)
                                .frame(width: max(1, currentRect.width), height: max(1, currentRect.height))
                                .position(x: currentRect.midX, y: currentRect.midY)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)

                            ZStack(alignment: .topLeading) {
                                destination
                                    .frame(width: targetRect.width, height: targetRect.height)
                                    .position(x: targetRect.midX, y: targetRect.midY)
                            }
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                                .opacity(contentProgress)
                                .offset(y: 8 * (1 - contentProgress))
                                .mask {
                                    GeometryReader { _ in
                                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                            .frame(
                                                width: max(1, currentRect.width),
                                                height: max(1, currentRect.height)
                                            )
                                            .position(x: currentRect.midX, y: currentRect.midY)
                                    }
                                }
                                .accessibilityAddTraits(.isModal)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .onAppear {
                            progress = 0
                            isClosing = false
                            activeDuration = animationDuration(from: localSourceRect, to: targetRect)
                            withAnimation(.spring(response: activeDuration, dampingFraction: 0.88, blendDuration: 0.05)) {
                                progress = 1
                            }
                        }
                    }
                    .zIndex(100)
                    .transition(.identity)
                }
            }
            // Define the named space outside the overlay so both the measured source and
            // the animated overlay are descendants of the same coordinate-space owner.
            .coordinateSpace(name: popInCoordinateSpaceName)
            .onAppear {
                if isPresented { isOverlayVisible = true }
            }
            .onChange(of: isPresented) { presented in
                if presented {
                    isOverlayVisible = true
                } else if progress > 0, !isClosing {
                    // A parent-driven dismissal must animate too; do not remove the overlay
                    // merely because the binding changed to false.
                    dismiss()
                } else if !isClosing {
                    isOverlayVisible = false
                    progress = 0
                }
            }
    }

    private func dismiss() {
        guard !isClosing else { return }
        isClosing = true
        let finishDismissal = {
            isOverlayVisible = false
            isPresented = false
            isClosing = false
        }
        if #available(iOS 17.0, macOS 14.0, *) {
            // Use the animation lifecycle callback so the final frame is not cut short.
            withAnimation(
                .spring(response: activeDuration, dampingFraction: 0.88, blendDuration: 0.05),
                completionCriteria: .removed
            ) {
                progress = 0
            } completion: {
                finishDismissal()
            }
        } else {
            // macOS 13 is retained as a package test host; iOS deployment starts at 17.
            withAnimation(.linear(duration: activeDuration)) { progress = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + activeDuration, execute: finishDismissal)
        }
    }

    private func animationDuration(from start: CGRect, to end: CGRect) -> Double {
        let distance = max(
            max(abs(Double(end.minX - start.minX)), abs(Double(end.minY - start.minY))),
            max(abs(Double(end.maxX - start.maxX)), abs(Double(end.maxY - start.maxY)))
        )
        // speed is normalized: 1.0 is the default pacing; higher values are faster.
        return min(0.72, max(0.28, distance / (1300 * speed)))
    }
}

private func smoothStep(from start: CGFloat, to end: CGFloat, value: CGFloat) -> CGFloat {
    guard end > start else { return value >= end ? 1 : 0 }
    let t = min(max((value - start) / (end - start), 0), 1)
    return t * t * (3 - 2 * t)
}

func aspectFitRect(in bounds: CGRect, aspectRatio: CGFloat) -> CGRect {
    guard bounds.width > 0, bounds.height > 0, aspectRatio > 0 else { return bounds }
    let boundsRatio = bounds.width / bounds.height
    let size: CGSize
    if boundsRatio > aspectRatio {
        size = CGSize(width: bounds.height * aspectRatio, height: bounds.height)
    } else {
        size = CGSize(width: bounds.width, height: bounds.width / aspectRatio)
    }
    return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
}

func interpolatePopInRect(from start: CGRect, to end: CGRect, progress: CGFloat) -> CGRect {
    let p = min(max(progress, 0), 1)
    let left = start.minX + (end.minX - start.minX) * p
    let top = start.minY + (end.minY - start.minY) * p
    let right = start.maxX + (end.maxX - start.maxX) * p
    let bottom = start.maxY + (end.maxY - start.maxY) * p
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}

public extension View {
    func popInSource(id: String) -> some View {
        modifier(PopInSource(id: id))
    }

    func popInTransition<Destination: View>(
        isPresented: Binding<Bool>,
        id: String,
        speed: Double = 1,
        destinationAspectRatio: CGFloat? = nil,
        sourceCornerRadius: CGFloat = 22,
        destinationCornerRadius: CGFloat = 0,
        backdropOpacity: Double = 0.14,
        backdropBlurOpacity: Double = 0.24,
        contentRevealStart: CGFloat = 0.24,
        contentRevealEnd: CGFloat = 0.68,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        modifier(PopInTransition(
            isPresented: isPresented,
            id: id,
            speed: speed,
            destinationAspectRatio: destinationAspectRatio,
            sourceCornerRadius: sourceCornerRadius,
            destinationCornerRadius: destinationCornerRadius,
            backdropOpacity: backdropOpacity,
            backdropBlurOpacity: backdropBlurOpacity,
            contentRevealStart: contentRevealStart,
            contentRevealEnd: contentRevealEnd,
            destination: destination
        ))
    }
}
