import SwiftUI

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
        public var backdrop: Color
        public var cornerRadius: CGFloat
        public var showsGrabber: Bool
        public var dismissOnBackdropTap: Bool
        public var dismissOnDrag: Bool

        public init(
            height: SheetCustomHeight = .fraction(0.62),
            background: Color? = nil,
            backdrop: Color = .black.opacity(0.34),
            cornerRadius: CGFloat = 26,
            showsGrabber: Bool = true,
            dismissOnBackdropTap: Bool = true,
            dismissOnDrag: Bool = true
        ) {
            self.height = height
            self.background = background ?? Self.defaultBackground
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
                        .frame(height: resolvedHeight(in: geometry.size.height))
                        .offset(y: max(0, dragOffset))
                        .transition(.move(edge: .bottom))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .all)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isPresented)
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
        .background(configuration.background)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: configuration.cornerRadius, topTrailingRadius: configuration.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .gesture(configuration.showsGrabber ? nil : dragGesture)
        .accessibilityAddTraits(.isModal)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                guard configuration.dismissOnDrag, value.translation.height > 100 || value.predictedEndTranslation.height > 160 else { return }
                dismiss()
            }
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
