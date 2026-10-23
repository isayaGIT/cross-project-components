import SwiftUI
import BottomSheet
#if canImport(BackgroundData)
import BackgroundData
#endif

/// Sizing strategy for a custom sheet, expressed in points or available-height fraction.
public enum SheetCustomHeight: Equatable {
    case fraction(CGFloat)
    case points(CGFloat)
}

/// Compatibility configuration retained for existing SheetCustom call sites.
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
    public var background: Color {
        didSet { usesDefaultMaterialBackground = false }
    }
    /// Uses the native translucent material when no background is explicitly supplied.
    fileprivate var usesDefaultMaterialBackground: Bool
    public var customBackground: Background?
    public var borderLine: AnyView?
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
        self.usesDefaultMaterialBackground = background == nil && customBackground == nil
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

/// Bottom-sheet adapter powered by lucaszischka/BottomSheet. The public API remains stable.
public struct SheetCustom<Content: View>: View {
    @Binding private var isPresented: Bool
    private let configuration: SheetCustomConfiguration
    private let content: Content

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
        Color.clear
            .bottomSheet(
                bottomSheetPosition: sheetPosition,
                switchablePositions: [.hidden, resolvedPosition],
                content: { content }
            )
            .showDragIndicator(configuration.showsGrabber)
            .dragIndicatorColor(.secondary.opacity(0.45))
            .enableTapToDismiss(configuration.dismissOnBackdropTap)
            .enableSwipeToDismiss(configuration.dismissOnDrag)
            .customAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88))
            .customBackground(sheetBackground)
            .onChange(of: isPresented) { _, presented in
                if !presented { sheetPosition.wrappedValue = .hidden }
                else { sheetPosition.wrappedValue = resolvedPosition }
            }
            .onChange(of: sheetPosition.wrappedValue) { _, position in
                isPresented = position != .hidden
            }
            .allowsHitTesting(isPresented)
            .accessibilityAddTraits(.isModal)
    }

    private var sheetPosition: Binding<BottomSheetPosition> {
        Binding(
            get: { isPresented ? resolvedPosition : .hidden },
            set: { isPresented = $0 != .hidden }
        )
    }

    private var resolvedPosition: BottomSheetPosition {
        switch configuration.height {
        case .fraction(let value): .relative(min(1, max(0.1, value)))
        case .points(let value): .absolute(max(1, value))
        }
    }

    private var sheetBackground: some View {
        Group {
            if let customBackground = configuration.customBackground {
                customBackground
            } else if configuration.usesDefaultMaterialBackground {
                // Match the translucent, blurred system-sheet appearance by default.
                Rectangle().fill(.regularMaterial)
            } else {
                configuration.background
            }
        }
        .overlay {
            if let border = configuration.border, configuration.borderWidth > 0 {
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: configuration.borderWidth)
            }
        }
        .overlay(alignment: .top) {
            if let borderLine = configuration.borderLine { borderLine }
        }
    }
}
