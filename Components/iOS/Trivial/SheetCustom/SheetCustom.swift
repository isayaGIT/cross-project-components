import SwiftUI
import Animated
#if canImport(UIKit)
import UIKit
#endif
#if canImport(BackgroundData)
import BackgroundData
#endif

/// Sizing strategy for a custom sheet, expressed in points or available-height fraction.
public enum SheetCustomHeight: Equatable {
    case fraction(CGFloat)
    case points(CGFloat)
}

public struct SheetCustomConfiguration {
    private static var defaultBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

        public var height: SheetCustomHeight
        public var background: Color
        public var customBackground: Background?
        public var borderLine: AnyView?
        /// Optional border drawn around the sheet's clipped outer shape.
        public var border: Color?
        public var borderWidth: CGFloat
        public var backdrop: Color
        public var cornerRadius: CGFloat
        public var showsGrabber: Bool
        public var dismissOnBackdropTap: Bool
        public var dismissOnDrag: Bool

        public init(
            height: SheetCustomHeight = .fraction(0.62),
            background: Color? = nil,
            customBackground: Background? = nil,
            borderLine: AnyView? = nil,
            border: Color? = nil,
            borderWidth: CGFloat = 1,
            backdrop: Color = .black.opacity(0.34),
            cornerRadius: CGFloat = 26,
            showsGrabber: Bool = true,
            dismissOnBackdropTap: Bool = true,
            dismissOnDrag: Bool = true
        ) {
            self.height = height
            self.background = background ?? Self.defaultBackground
            self.customBackground = customBackground
            self.borderLine = borderLine
            self.border = border
            self.borderWidth = max(0, borderWidth)
            self.backdrop = backdrop
            self.cornerRadius = max(0, cornerRadius)
            self.showsGrabber = showsGrabber
            self.dismissOnBackdropTap = dismissOnBackdropTap
            self.dismissOnDrag = dismissOnDrag
        }
}

/// A lightweight, fully custom bottom sheet. The presenter owns visibility and content.
public struct SheetCustom<Content: View>: View {
    @Binding private var isPresented: Bool
    private let configuration: SheetCustomConfiguration
    private let content: Content
    @GestureState private var dragOffset: CGFloat = 0

    public init(
        isPresented: Binding<Bool>,
        configuration: SheetCustomConfiguration = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.configuration = configuration
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            if isPresented {
                ZStack(alignment: .bottom) {
                    configuration.backdrop
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard configuration.dismissOnBackdropTap else { return }
                            dismiss()
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Dismiss sheet")

                    panel
                        .frame(height: resolvedHeight(in: presentationHeight(fallback: geometry.size.height)))
                        .offset(y: max(0, dragOffset))
                        .slideDownDismiss(isPresented: isPresented)
                        .animation(SlideDownDismiss.animation, value: dragOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            if configuration.showsGrabber {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .accessibilityHidden(true)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background {
            Group {
                if let customBackground = configuration.customBackground { customBackground }
                else { Background(color: configuration.background) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: configuration.cornerRadius, topTrailingRadius: configuration.cornerRadius, style: .continuous))
        .overlay {
            if let border = configuration.border, configuration.borderWidth > 0 {
                UnevenRoundedRectangle(topLeadingRadius: configuration.cornerRadius, topTrailingRadius: configuration.cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: configuration.borderWidth)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if let borderLine = configuration.borderLine { borderLine.frame(maxWidth: .infinity).allowsHitTesting(false) }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityAddTraits(.isModal)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                // Track the finger directly while dragging down; resist upward movement.
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                guard configuration.dismissOnDrag else { return }
                let distance = value.translation.height
                let projectedDistance = value.predictedEndTranslation.height
                let screenHeight = presentationHeight(fallback: 0)
                // Dismiss only after the panel has been dragged far enough that
                // roughly the lower third of the screen remains covered by it.
                let dismissalDistance = max(1, resolvedHeight(in: screenHeight) - screenHeight / 3)
                if distance >= dismissalDistance || projectedDistance >= dismissalDistance {
                    // Let the panel finish following the gesture before dismissing.
                    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88)) {
                        dismiss()
                    }
                }
            }
    }

    /// Prefer the hosting window's full height over GeometryReader's proposed height.
    /// SheetCustom is often mounted in an overlay, where the proposed height can be
    /// constrained by the presenting content instead of representing the whole screen.
    private func presentationHeight(fallback: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let windowHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.height
        if let windowHeight, windowHeight > 0 {
            return windowHeight
        }
        #endif
        return fallback
    }

    private func resolvedHeight(in availableHeight: CGFloat) -> CGFloat {
        switch configuration.height {
        case .fraction(let fraction):
            return min(availableHeight, max(1, availableHeight * min(1, max(0.1, fraction))))
        case .points(let points):
            return min(availableHeight, max(1, points))
        }
    }

    private func dismiss() {
        isPresented = false
    }
}
