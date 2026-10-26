import SwiftUI

/// Owns the complete input region: controls, panel state, and cross-component layout.
/// `InputBar` is only the capsule visual surface behind the controls.
public struct InputContainer: View {
    @Binding private var text: String
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isTextFieldFocused: Bool
    @State private var localStickerPanelPresented = false

    private let isGenerating: Bool
    private let configuration: ScreenChatConfig
    private let stickerKeyboardConfiguration: StickerKeyboard.Configuration
    private let inputContext: ScreenChatContainerInputContext?
    private let stickerPanelBinding: Binding<Bool>?
    @Binding private var isToolsPanelPresented: Bool
    private let accessoryPanel: AnyView?
    private let toolsPanel: AnyView?
    private let onSend: () -> Void
    private let onStop: (() -> Void)?
    private let onAttach: (() -> Void)?

    public init(
        text: Binding<String>,
        isGenerating: Bool = false,
        configuration: ScreenChatConfig,
        stickerKeyboardConfiguration: StickerKeyboard.Configuration = .standard,
        inputContext: ScreenChatContainerInputContext? = nil,
        isStickerPanelPresented: Binding<Bool>? = nil,
        isToolsPanelPresented: Binding<Bool> = .constant(false),
        accessoryPanel: AnyView? = nil,
        toolsPanel: AnyView? = nil,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil
    ) {
        self._text = text
        self.isGenerating = isGenerating
        self.configuration = configuration
        self.stickerKeyboardConfiguration = stickerKeyboardConfiguration
        self.inputContext = inputContext
        self.stickerPanelBinding = isStickerPanelPresented
        self._isToolsPanelPresented = isToolsPanelPresented
        self.accessoryPanel = accessoryPanel
        self.toolsPanel = toolsPanel
        self.onSend = onSend
        self.onStop = onStop
        self.onAttach = onAttach
    }

    private var stickerPanelPresented: Bool {
        stickerPanelBinding?.wrappedValue ?? inputContext?.isStickerPanelPresented.wrappedValue ?? localStickerPanelPresented
    }

    private var toolsPresented: Bool { isToolsPanelPresented }
    private var canSend: Bool { !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        VStack(spacing: 0) {
            // Keep the input bar above its expanded panel. The panel participates
            // in normal layout, so it pushes the bar upward instead of covering it.
            composer

            if toolsPresented, let toolsPanel {
                toolsPanel.transition(.move(edge: .bottom).combined(with: .opacity))
            } else if stickerPanelPresented, let accessoryPanel {
                accessoryPanel
                    .overlay(alignment: .topTrailing) {
                        if canSend && !isGenerating {
                            ButtonCustom(
                                systemName: "arrow.up",
                                color: configuration.themeColors?.input.floatingSendForeground ?? stickerKeyboardConfiguration.sendButtonFontColor,
                                size: stickerKeyboardConfiguration.sendButtonSize,
                                iconSize: stickerKeyboardConfiguration.sendButtonFontSize,
                                texture: .color(configuration.themeColors?.input.floatingSendBackground ?? stickerKeyboardConfiguration.sendButtonBackground),
                                border: configuration.themeColors?.input.floatingSendBorder ?? stickerKeyboardConfiguration.sendButtonBorder,
                                accessibilityLabel: "Send message",
                                action: submit
                            )
                            .padding(.trailing, 14)
                            .offset(y: -stickerKeyboardConfiguration.sendButtonSize * 0.55)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: toolsPresented)
        .animation(.easeInOut(duration: 0.22), value: stickerPanelPresented)
        .foregroundStyle(configuration.inputTextColor)
        .tint(configuration.inputIconColor)
        .padding(.horizontal, 12)
        .padding(.bottom, 7)
        .padding(.top, 8)
    }

    private var composer: some View {
        ZStack {
            InputBar(background: configuration.themeColors?.input.composerSurface, usesGlass: configuration.usesGlassSurfaces)
            HStack(spacing: 8) {
                TextField("Message", text: $text, prompt: Text("Message").foregroundColor(configuration.themeColors?.input.placeholder ?? .secondary), axis: .horizontal)
                    .font(configuration.themeFonts?.input.textEntry ?? .system(size: 16))
                    .foregroundStyle(configuration.themeColors?.input.typedText ?? configuration.inputTextColor)
                    .lineLimit(1...1)
                    .submitLabel(.send)
                    .focused(inputContext == nil ? $isTextFieldFocused : inputContext!.focus)
                    .onTapGesture {
                        // Tapping the composer switches back to text entry rather
                        // than leaving the sticker panel visible behind the IME.
                        dismissPanelsForTextEntry()
                    }
                    .onSubmit(submit)
                    .accessibilityLabel("Message")
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                // Keep both utility controls inside the capsule, immediately
                // to the right of the text field and close to one another.
                accessoryButtonCluster

                if isGenerating {
                    Button { onStop?() } label: {
                        Image(systemName: "stop.fill")
                            .font(configuration.themeFonts?.input.stopIcon ?? .system(size: 13, weight: .semibold))
                            .foregroundStyle(configuration.themeColors?.input.stopForeground ?? actionForeground)
                            .frame(width: 34, height: 34)
                            .background(configuration.themeColors?.input.stopBackground ?? actionBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onStop == nil)
                    .accessibilityLabel("Stop generating")
                } else if canSend {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(configuration.themeFonts?.input.sendIcon ?? .system(size: 16, weight: .semibold))
                            .foregroundStyle(configuration.themeColors?.input.sendForeground ?? actionForeground)
                            .frame(width: 34, height: 34)
                            .background(configuration.themeColors?.input.sendBackground ?? actionBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actionBackground: Color { Color.primary }
    private var actionForeground: Color { colorScheme == .dark ? .black : .white }

    /// The two utility buttons deliberately overlap to form a third, themeable
    /// intersection color. Each circle and the intersection are drawn separately
    /// so the cross-section remains visible instead of being hidden by the top button.
    private var accessoryButtonCluster: some View {
        let diameter: CGFloat = 44
        let gap: CGFloat = 4
        let clusterWidth = diameter * 2 + gap

        return ZStack {
            HStack(spacing: gap) {
                accessoryButtonSurface(diameter: diameter)
                accessoryButtonSurface(diameter: diameter)
            }
            HStack(spacing: gap) {
                accessoryButton(
                    systemName: stickerPanelPresented ? "keyboard" : nil,
                    usesSmileyFace: !stickerPanelPresented,
                    label: stickerPanelPresented ? "Show system keyboard" : "Show sticker keyboard",
                    action: toggleStickerPanel
                )
                .disabled(accessoryPanel == nil)
                .opacity(accessoryPanel == nil ? 0.72 : 1)

                accessoryButton(
                    systemName: "plus",
                    label: toolsPresented ? "Close actions" : "Open actions",
                    action: toggleTools
                )
            }
        }
        .frame(width: clusterWidth, height: diameter)
        .accessibilityElement(children: .contain)
    }


    @ViewBuilder
    private func accessoryButtonSurface(diameter: CGFloat) -> some View {
        if configuration.usesGlassSurfaces {
            Circle().fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.76), lineWidth: 1))
                .frame(width: diameter, height: diameter)
        } else {
            Circle().fill(configuration.inputAccessoryButtonBackground)
                .frame(width: diameter, height: diameter)
        }
    }

    private func accessoryButton(
        systemName: String?,
        usesSmileyFace: Bool = false,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if usesSmileyFace {
                    ComponentIcons.smileyFace
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(configuration.inputAccessoryButtonForeground)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(configuration.inputAccessoryIconFont)
                        .foregroundStyle(configuration.inputAccessoryButtonForeground)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dismissPanelsForTextEntry() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isToolsPanelPresented = false
            setStickerPanelPresented(false)
        }
    }

    private func toggleTools() {
        guard toolsPanel != nil else {
            onAttach?()
            return
        }
        let nextValue = !isToolsPanelPresented
        withAnimation(.easeInOut(duration: 0.22)) {
            isToolsPanelPresented = nextValue
            setStickerPanelPresented(false)
        }
        if nextValue {
            setFocused(false)
        }
    }

    private func toggleStickerPanel() {
        guard accessoryPanel != nil else { return }
        if stickerPanelPresented {
            withAnimation(.easeInOut(duration: 0.22)) { setStickerPanelPresented(false) }
            setFocused(true)
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                isToolsPanelPresented = false
                setStickerPanelPresented(true)
            }
            setFocused(false)
        }
    }

    private func setStickerPanelPresented(_ presented: Bool) {
        if let stickerPanelBinding {
            stickerPanelBinding.wrappedValue = presented
        } else if let binding = inputContext?.isStickerPanelPresented {
            binding.wrappedValue = presented
        } else {
            localStickerPanelPresented = presented
        }
    }

    private func setFocused(_ focused: Bool) {
        if let inputContext { inputContext.focus.wrappedValue = focused }
        else { isTextFieldFocused = focused }
    }

    private func submit() {
        guard canSend else { return }
        setStickerPanelPresented(false)
        isToolsPanelPresented = false
        onSend()
    }
}

