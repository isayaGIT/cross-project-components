import SwiftUI

/// A reusable shell that reveals a leading sidebar by shifting its content as one layer.
/// The container owns the coordinated theme; supplied sidebar content must consume `theme.sidebar` explicitly.
public struct ScreenChatContainer<Sidebar: View, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissBottomSheet) private var dismissBottomSheet
    @State private var isSidebarOpen = false
    @State private var isThemePickerPresented = false
    @State private var isStickerPanelPresented = false
    @State private var isHostedSheetPresented = false
    @State private var isHostedOverlayPresented = false
    @State private var hostedOverlayContent = AnyView(EmptyView())
    @State private var hostedOverlayBackdrop: Color = .black.opacity(0.34)
    @State private var hostedOverlayDismissOnBackdropTap = true
    @State private var hostedSheetContent = AnyView(EmptyView())
    @State private var hostedSheetConfiguration = BottomSheetPresentationConfiguration()
    @FocusState private var isChatInputFocused: Bool
    @State private var selectedTheme: ScreenChatTheme
    @State private var activeTheme: ScreenChatContainerTheme
    private let usesPresetDefaults: Bool

    private let sidebarWidth: CGFloat
    private let sidebar: (@escaping () -> Void, SidebarAppearance) -> Sidebar
    private let content: (ScreenChatConfig, ScreenChatContainerInputContext) -> Content

    public init(
        sidebarWidth: CGFloat = 300,
        theme: ScreenChatContainerTheme? = nil,
        initialPreset: ScreenChatTheme = .sculpted,
        @ViewBuilder sidebar: @escaping (@escaping () -> Void, SidebarAppearance) -> Sidebar,
        @ViewBuilder content: @escaping (ScreenChatConfig, ScreenChatContainerInputContext) -> Content
    ) {
        self.sidebarWidth = max(0, sidebarWidth)
        self.sidebar = sidebar
        self.content = content
        _selectedTheme = State(initialValue: initialPreset)
        _activeTheme = State(initialValue: theme ?? .preset(initialPreset))
        usesPresetDefaults = theme == nil
    }

    public var body: some View {
        GeometryReader { geometry in
            let revealWidth = min(sidebarWidth, geometry.size.width * 0.82)
            ZStack(alignment: .leading) {
                sidebar(closeSidebar, activeTheme.sidebar)
                    .frame(width: revealWidth, height: geometry.size.height, alignment: .topLeading)
                    .background {
                        if selectedTheme == .dreamveil { DreamveilBackdrop() }
                        else { activeTheme.container.background }
                    }
                    .accessibilityHidden(!isSidebarOpen)

                content(activeTheme.screenChat, ScreenChatContainerInputContext(
                    focus: $isChatInputFocused,
                    isStickerPanelPresented: $isStickerPanelPresented,
                    dismissKeyboard: dismissKeyboard,
                    presentBottomSheet: presentHostedSheet,
                    presentOverlay: presentHostedOverlay,
                    dismissOverlay: dismissHostedOverlay
                ))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(activeTheme.container.contentSurface)
                    .overlay(alignment: .topLeading) {
                        Button(action: toggleSidebar) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(activeTheme.screenChat.headerIconColor)
                                .frame(width: 36, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 7)
                        .padding(.leading, 12)
                        .accessibilityLabel("展开聊天列表")
                        .accessibilityHint("打开侧边栏")
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { isThemePickerPresented = true } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(activeTheme.themeButton.foreground)
                                .frame(width: 36, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ThemePickerButtonStyle(appearance: activeTheme.themeButton))
                        .padding(.top, 7)
                        .padding(.trailing, 54)
                        .accessibilityLabel("聊天主题")
                        .accessibilityHint("打开主题选择")
                    }
                    .shadow(color: .black.opacity(isSidebarOpen ? 0.16 : 0), radius: 16, x: -4, y: 0)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(activeTheme.container.separator).frame(width: 1).opacity(isSidebarOpen ? 1 : 0)
                    }
                    .offset(x: isSidebarOpen ? revealWidth : 0)
                    // Keep the shifted chat from intercepting taps in its original layout frame.
                    .allowsHitTesting(!isSidebarOpen)
                    .overlay(alignment: .leading) {
                        if isSidebarOpen {
                            Color.clear
                                .frame(width: max(0, geometry.size.width - revealWidth))
                                .contentShape(Rectangle())
                                .onTapGesture(perform: closeSidebar)
                                .offset(x: revealWidth)
                        }
                    }
                    // Offset changes where the chat is drawn, but its original layout region can
                    // still win hit testing. The close target above remains interactive.
                    .accessibilityAction(named: Text("切换聊天列表"), toggleSidebar)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
        }
        .background {
            if selectedTheme == .dreamveil { DreamveilBackdrop().ignoresSafeArea() }
            else { activeTheme.container.background.ignoresSafeArea() }
        }
        .overlay {
            ZStack {
                OverlayPresenter(
                    isPresented: $isThemePickerPresented,
                    configuration: BottomSheetPresentationConfiguration(
                        height: .fraction(0.72),
                        background: activeTheme.colors.themePicker.sheetBackground
                    )
                ) { themePicker }

                OverlayPresenter(
                    isPresented: $isHostedSheetPresented,
                    configuration: hostedSheetConfiguration
                ) { hostedSheetContent }

                OverlayPresenter(
                    isPresented: $isHostedOverlayPresented,
                    backdrop: hostedOverlayBackdrop,
                    dismissOnBackdropTap: hostedOverlayDismissOnBackdropTap
                ) { hostedOverlayContent }
            }
        }
        .onAppear {
            if usesPresetDefaults { activeTheme = .preset(selectedTheme, colorScheme: colorScheme) }
        }
        .onChange(of: colorScheme) { _, newScheme in
            if selectedTheme == .system { activeTheme = .preset(.system, colorScheme: newScheme) }
        }
    }

    private var themePicker: some View {
        NavigationStack {
            List {
                ForEach(ScreenChatTheme.allCases) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTheme = preset
                            activeTheme = .preset(preset, colorScheme: colorScheme)
                        }
                        dismissBottomSheet()
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(ScreenChatThemes.previewColor(for: preset))
                                .frame(width: 42, height: 42)
                                .overlay { Image(systemName: preset.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.title).font(activeTheme.fonts.container.presetTitle).foregroundStyle(activeTheme.colors.themePicker.presetTitle)
                                Text(preset.subtitle).font(activeTheme.fonts.container.presetSubtitle).foregroundStyle(activeTheme.colors.themePicker.presetSubtitle)
                            }
                            Spacer()
                            if selectedTheme == preset { Image(systemName: "checkmark.circle.fill").foregroundStyle(activeTheme.colors.themePicker.selectedIndicator).font(.system(size: activeTheme.fonts.container.selectedIndicatorSize)) }
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("整体主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismissBottomSheet() } } }
        }
    }

    private func presentHostedSheet(_ content: AnyView, configuration: BottomSheetPresentationConfiguration) {
        hostedSheetContent = content
        hostedSheetConfiguration = configuration
        isHostedSheetPresented = true
    }

    private func presentHostedOverlay(_ content: AnyView, backdrop: Color, dismissOnBackdropTap: Bool) {
        hostedOverlayContent = content
        hostedOverlayBackdrop = backdrop
        hostedOverlayDismissOnBackdropTap = dismissOnBackdropTap
        isHostedOverlayPresented = true
    }

    private func dismissHostedOverlay() {
        isHostedOverlayPresented = false
    }

    private func dismissKeyboard() {
        isChatInputFocused = false
        isStickerPanelPresented = false
    }

    private func toggleSidebar() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.01) : .spring(response: 0.36, dampingFraction: 0.88)) {
            isSidebarOpen.toggle()
        }
    }

    private func closeSidebar() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.01) : .spring(response: 0.36, dampingFraction: 0.88)) {
            isSidebarOpen = false
        }
    }
}

/// Shared input interaction state owned by ScreenChatContainer so keyboard and accessory-panel
/// transitions are coordinated with the whole content layer.
public struct ScreenChatContainerInputContext {
    public let focus: FocusState<Bool>.Binding
    public let isStickerPanelPresented: Binding<Bool>
    public let dismissKeyboard: () -> Void
    public let presentBottomSheet: (AnyView, BottomSheetPresentationConfiguration) -> Void
    public let presentOverlay: (AnyView, Color, Bool) -> Void
    public let dismissOverlay: () -> Void

    public init(
        focus: FocusState<Bool>.Binding,
        isStickerPanelPresented: Binding<Bool>,
        dismissKeyboard: @escaping () -> Void,
        presentBottomSheet: @escaping (AnyView, BottomSheetPresentationConfiguration) -> Void,
        presentOverlay: @escaping (AnyView, Color, Bool) -> Void,
        dismissOverlay: @escaping () -> Void
    ) {
        self.focus = focus
        self.isStickerPanelPresented = isStickerPanelPresented
        self.dismissKeyboard = dismissKeyboard
        self.presentBottomSheet = presentBottomSheet
        self.presentOverlay = presentOverlay
        self.dismissOverlay = dismissOverlay
    }
}

private struct ThemePickerButtonStyle: ButtonStyle {
    let appearance: ThemeButtonAppearance
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? appearance.pressedBackground : appearance.background, in: RoundedRectangle(cornerRadius: 10))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}


/// Asset-free soft-focus atmosphere for the Dreamveil theme.
private struct DreamveilBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(hex: 0xFDF4FF), Color(hex: 0xEDE8FF), Color(hex: 0xE5F1FF), Color(hex: 0xFFF0F7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(Color(hex: 0xF6BFE2).opacity(0.58)).frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.42).blur(radius: 72).offset(x: -proxy.size.width * 0.28, y: -proxy.size.height * 0.28)
                Ellipse().fill(Color(hex: 0xBDB4FF).opacity(0.55)).frame(width: proxy.size.width * 0.92, height: proxy.size.height * 0.44).blur(radius: 82).offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.02)
                Ellipse().fill(Color(hex: 0xB9DDFB).opacity(0.55)).frame(width: proxy.size.width * 0.95, height: proxy.size.height * 0.40).blur(radius: 84).offset(x: -proxy.size.width * 0.08, y: proxy.size.height * 0.36)
                Ellipse().fill(Color.white.opacity(0.8)).frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.25).blur(radius: 68).offset(x: proxy.size.width * 0.24, y: proxy.size.height * 0.46)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
