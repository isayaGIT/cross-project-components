import SwiftUI
import BottomSheet

/// Sizing for the shared presentation sheet.
public enum BottomSheetHeight: Equatable {
    case fraction(CGFloat)
    case points(CGFloat)
}

/// Shared appearance and dismissal policy for library-owned bottom sheets.
public struct BottomSheetPresentationConfiguration {
    public var height: BottomSheetHeight
    public var background: Color
    public var backdrop: Color
    public var border: Color?
    public var borderWidth: CGFloat
    public var topBorderLine: AnyView?
    public var cornerRadius: CGFloat
    public var showsGrabber: Bool
    public var dismissOnBackdropTap: Bool
    public var dismissOnDrag: Bool
    public var motion: any BottomSheetMotionConfigProtocol

    private static var platformBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    public init(
        height: BottomSheetHeight = .fraction(0.62),
        background: Color? = nil,
        backdrop: Color = .black.opacity(0.34),
        border: Color? = nil,
        borderWidth: CGFloat = 1,
        topBorderLine: AnyView? = nil,
        cornerRadius: CGFloat = 26,
        showsGrabber: Bool = true,
        dismissOnBackdropTap: Bool = true,
        dismissOnDrag: Bool = true,
        motion: any BottomSheetMotionConfigProtocol = StandardBottomSheetMotionConfig.standard
    ) {
        self.height = height
        self.background = background ?? Self.platformBackground
        self.backdrop = backdrop
        self.border = border
        self.borderWidth = max(0, borderWidth)
        self.topBorderLine = topBorderLine
        self.cornerRadius = max(0, cornerRadius)
        self.showsGrabber = showsGrabber
        self.dismissOnBackdropTap = dismissOnBackdropTap
        self.dismissOnDrag = dismissOnDrag
        self.motion = motion
    }
}

private struct BottomSheetDismissActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

public extension EnvironmentValues {
    /// Dismisses the nearest presented overlay, including a bottom sheet.
    var dismissBottomSheet: () -> Void {
        get { self[BottomSheetDismissActionKey.self] }
        set { self[BottomSheetDismissActionKey.self] = newValue }
    }
}

/// Shared presentation host for dimmed overlays and bottom sheets.
/// The host owns backdrop rendering, z-order, presentation state, and dismissal.
/// Use the `configuration` initializer for a bottom sheet, or `backdrop` for a
/// custom-positioned overlay such as a calendar.
public struct OverlayPresenter<Content: View>: View {
    @Binding private var isPresented: Bool
    private let configuration: BottomSheetPresentationConfiguration
    private let content: Content
    private let presentsBottomSheet: Bool
    private let customBackdrop: Color
    private let dismissOnBackdropTap: Bool

    public init(
        isPresented: Binding<Bool>,
        configuration: BottomSheetPresentationConfiguration = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.configuration = configuration
        self.content = content()
        self.presentsBottomSheet = true
        self.customBackdrop = configuration.backdrop
        self.dismissOnBackdropTap = configuration.dismissOnBackdropTap
    }

    public init(
        isPresented: Binding<Bool>,
        backdrop: Color = .black.opacity(0.34),
        dismissOnBackdropTap: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.configuration = .init(backdrop: backdrop, showsGrabber: false, dismissOnDrag: false)
        self.content = content()
        self.presentsBottomSheet = false
        self.customBackdrop = backdrop
        self.dismissOnBackdropTap = dismissOnBackdropTap
    }

    public var body: some View {
        ZStack {
            if isPresented {
                customBackdrop
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissOnBackdropTap else { return }
                        isPresented = false
                    }
                    .accessibilityLabel("关闭遮罩")
                    .transition(.opacity.animation(configuration.motion.backdropAnimation))

                if presentsBottomSheet {
                    Color.clear
                    .bottomSheet(
                        bottomSheetPosition: sheetPosition,
                        switchablePositions: [.hidden, resolvedPosition],
                        content: { sheetContent }
                    )
                    .showDragIndicator(configuration.showsGrabber)
                    .dragIndicatorColor(.secondary.opacity(0.45))
                    .enableTapToDismiss(configuration.dismissOnBackdropTap)
                    .enableSwipeToDismiss(configuration.dismissOnDrag)
                    .customAnimation(configuration.motion.sheetAnimation)
                    .customBackground(sheetBackground)
                    .onChange(of: isPresented) { _, presented in
                        sheetPosition.wrappedValue = presented ? resolvedPosition : .hidden
                    }
                    .onChange(of: sheetPosition.wrappedValue) { _, position in
                        isPresented = position != .hidden
                    }
                    .transition(.opacity.animation(configuration.motion.backdropAnimation))
                } else {
                    content
                        .environment(\.dismissBottomSheet, { isPresented = false })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.animation(configuration.motion.backdropAnimation))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(configuration.motion.backdropAnimation, value: isPresented)
        .accessibilityAddTraits(isPresented ? .isModal : AccessibilityTraits())
    }

    private var sheetContent: some View {
        content
            .environment(\.dismissBottomSheet, { isPresented = false })
            .background(configuration.background)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
    }

    private var sheetBackground: some View {
        configuration.background
            .overlay {
                if let border = configuration.border, configuration.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                        .stroke(border, lineWidth: configuration.borderWidth)
                }
            }
            .overlay(alignment: .top) {
                if let topBorderLine = configuration.topBorderLine { topBorderLine }
            }
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
}

/// Compatibility alias for existing call sites; new code should use `OverlayPresenter`.
public typealias BottomSheetPresenter<Content: View> = OverlayPresenter<Content>
