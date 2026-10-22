import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The reusable SwiftUI chat composer extracted from ZPing's `InputSection`.
///
/// The consuming app owns microphone permission, recording, transcription,
/// attachment presentation, and message delivery. This view owns the composer
/// layout and reports user intent through callbacks.
public struct MessageComposer: View {
    public enum InputMode: Equatable {
        case voice
        case text
    }

    public enum VoiceState: Equatable {
        case idle
        case recording
        case transcribing
    }

    /// Appearance defaults are read from the package's shared JSON design palette.
    /// Pass explicit overrides when a consuming app needs a different appearance.
    public struct Style {
        public var accent: Color
        public var barBackground: Color
        public var fieldBackground: Color
        public var textColor: Color
        public var secondaryTextColor: Color
        public var placeholderColor: Color
        public var borderColor: Color
        public var dangerColor: Color
        public var buttonBackground: Color
        public var buttonForeground: Color
        public var disabledBackground: Color
        public var waveformBaseColor: Color
        public var shadowColor: Color
        public var actionPressedBackground: Color
        public var actionBorderColor: Color
        public var waveformGlowColor: Color

        public init(
            accent: Color = ComponentDesignPalette.warmEmber.accent,
            barBackground: Color = ComponentDesignPalette.warmEmber.barBackground,
            fieldBackground: Color = ComponentDesignPalette.warmEmber.fieldBackground,
            textColor: Color = ComponentDesignPalette.warmEmber.textColor,
            secondaryTextColor: Color = ComponentDesignPalette.warmEmber.secondaryTextColor,
            placeholderColor: Color = ComponentDesignPalette.warmEmber.placeholderColor,
            borderColor: Color = ComponentDesignPalette.warmEmber.borderColor,
            dangerColor: Color = ComponentDesignPalette.warmEmber.dangerColor,
            buttonBackground: Color = ComponentDesignPalette.warmEmber.buttonBackground,
            buttonForeground: Color = ComponentDesignPalette.warmEmber.buttonForeground,
            disabledBackground: Color = ComponentDesignPalette.warmEmber.disabledBackground,
            waveformBaseColor: Color = ComponentDesignPalette.warmEmber.waveformBaseColor,
            shadowColor: Color = ComponentDesignPalette.warmEmber.shadowColor,
            actionPressedBackground: Color = ComponentDesignPalette.warmEmber.actionPressedBackground,
            actionBorderColor: Color = ComponentDesignPalette.warmEmber.actionBorderColor,
            waveformGlowColor: Color = ComponentDesignPalette.warmEmber.waveformGlowColor
        ) {
            self.accent = accent
            self.barBackground = barBackground
            self.fieldBackground = fieldBackground
            self.textColor = textColor
            self.secondaryTextColor = secondaryTextColor
            self.placeholderColor = placeholderColor
            self.borderColor = borderColor
            self.dangerColor = dangerColor
            self.buttonBackground = buttonBackground
            self.buttonForeground = buttonForeground
            self.disabledBackground = disabledBackground
            self.waveformBaseColor = waveformBaseColor
            self.shadowColor = shadowColor
            self.actionPressedBackground = actionPressedBackground
            self.actionBorderColor = actionBorderColor
            self.waveformGlowColor = waveformGlowColor
        }

        public static let zping = Style()
    }

    @Binding private var text: String
    @Binding private var mode: InputMode
    @Binding private var voiceState: VoiceState

    private let audioLevels: [Float]
    private let voiceError: String?
    private let placeholder: String
    private let maximumLines: Int
    private let showsCallButton: Bool
    private let style: Style
    private let onBarHeightChange: ((CGFloat) -> Void)?
    private let onSend: (String) -> Void
    private let onStartVoice: () -> Void
    private let onStopVoice: () -> Void
    private let onCancelVoice: () -> Void
    private let onDirectSend: () -> Void
    private let onAddAttachment: () -> Void
    private let onCall: () -> Void
    private let onModeChange: ((InputMode) -> Void)?
    private let onActionPressChanged: ((Bool) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isActionPressed = false

    public init(
        text: Binding<String>,
        mode: Binding<InputMode>,
        voiceState: Binding<VoiceState>,
        audioLevels: [Float] = [],
        voiceError: String? = nil,
        placeholder: String = "输入消息...",
        maximumLines: Int = ComponentDesignMetrics.warmEmber.defaultMaximumLines,
        showsCallButton: Bool = true,
        style: Style = .zping,
        onBarHeightChange: ((CGFloat) -> Void)? = nil,
        onSend: @escaping (String) -> Void,
        onStartVoice: @escaping () -> Void = {},
        onStopVoice: @escaping () -> Void = {},
        onCancelVoice: @escaping () -> Void = {},
        onDirectSend: @escaping () -> Void = {},
        onAddAttachment: @escaping () -> Void = {},
        onCall: @escaping () -> Void = {},
        onModeChange: ((InputMode) -> Void)? = nil,
        onActionPressChanged: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self._mode = mode
        self._voiceState = voiceState
        self.audioLevels = audioLevels
        self.voiceError = voiceError
        self.placeholder = placeholder
        self.maximumLines = max(1, maximumLines)
        self.showsCallButton = showsCallButton
        self.style = style
        self.onBarHeightChange = onBarHeightChange
        self.onSend = onSend
        self.onStartVoice = onStartVoice
        self.onStopVoice = onStopVoice
        self.onCancelVoice = onCancelVoice
        self.onDirectSend = onDirectSend
        self.onAddAttachment = onAddAttachment
        self.onCall = onCall
        self.onModeChange = onModeChange
        self.onActionPressChanged = onActionPressChanged
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: .zero) {
            if let voiceError {
                errorBanner(voiceError)
            }

            barContent
                .overlay(alignment: .top) {
                    if voiceState == .recording {
                        actionBracketButton
                            .padding(.horizontal, metrics.actionButtonHorizontalPadding)
                            .padding(.bottom, metrics.actionButtonBottomPadding)
                            .alignmentGuide(.top) { dimensions in dimensions[.bottom] }
                            .offset(
                                y: -((metrics.actionBracketDiameter / 2) + metrics.actionButtonVerticalGap)
                                    - metrics.actionButtonAdditionalOffset
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
        }
        .onChangeCompat(of: mode) { newMode in
            isFocused = newMode == .text
        }
        .onChangeCompat(of: voiceState) { newState in
            if newState != MessageComposer.VoiceState.idle { isFocused = false }
        }
    }

    private var barContent: some View {
        VStack(spacing: .zero) {
            Rectangle()
                .fill(style.borderColor)
                .frame(height: metrics.separatorThickness)

            if voiceState == .idle {
                HStack(alignment: .center, spacing: metrics.buttonGap) {
                    leftZone
                    centerZone
                    rightZone
                }
                .animation(.easeInOut(duration: metrics.transitionDuration), value: voiceState)
                .animation(.easeInOut(duration: metrics.transitionDuration), value: mode)
                .padding(.horizontal, metrics.barHorizontalPadding)
                .padding(.vertical, metrics.barVerticalPadding)
            } else {
                HStack(alignment: .center, spacing: metrics.buttonGap) {
                    leftZone
                    centerZone
                }
                .animation(.easeInOut(duration: metrics.transitionDuration), value: voiceState)
                .animation(.easeInOut(duration: metrics.transitionDuration), value: mode)
                .padding(.horizontal, metrics.barHorizontalPadding)
                .padding(.vertical, metrics.barVerticalPadding)
            }
        }
        .background(style.barBackground)
        .background {
            GeometryReader { geometry in
                ComponentDesignPalette.warmEmber.transparent
                    .onAppear { onBarHeightChange?(geometry.size.height) }
                    .onChangeCompat(of: geometry.size.height) { height in onBarHeightChange?(height) }
            }
        }
    }

    @ViewBuilder
    private var leftZone: some View {
        switch voiceState {
        case .idle:
            iconButton("plus", label: "添加附件", appearance: .plain, action: onAddAttachment)
        case .recording:
            iconButton("stop.fill", label: "停止录音", appearance: .plain, action: onStopVoice)
        case .transcribing:
            iconButton("xmark", label: "取消语音输入", appearance: .plain, action: onCancelVoice)
        }
    }

    @ViewBuilder
    private var centerZone: some View {
        HStack(alignment: .center, spacing: metrics.buttonGap) {
            switch (mode, voiceState) {
            case (.voice, .idle):
                voiceCapsuleButton
            case (.text, .idle):
                textField
            case (_, .recording):
                waveform
                iconButton("arrow.up", label: "转录后发送", appearance: .accent, action: onDirectSend)
                    .transition(.opacity)
            case (_, .transcribing):
                HStack(spacing: metrics.statusSpacing) {
                    ProgressView().controlSize(.small).tint(style.secondaryTextColor)
                    Text("正在转录...")
                        .font(.system(size: metrics.statusFontSize))
                        .foregroundStyle(style.secondaryTextColor)
                    Spacer(minLength: .zero)
                }
                .frame(minHeight: metrics.controlDiameter)
                .padding(.leading, metrics.statusLeadingPadding)
                iconButton("arrow.up", label: "正在转录", appearance: .disabled, action: {})
                    .disabled(true)
            }
        }
    }

    @ViewBuilder
    private var rightZone: some View {
        if mode == .voice {
            iconButton("keyboard", label: "切换到键盘输入", appearance: .plain) {
                setMode(.text)
            }
            if showsCallButton {
                iconButton("phone.fill", label: "开始通话", appearance: .circular, action: onCall)
            }
        } else {
            iconButton("mic.fill", label: "语音输入", appearance: .plain, action: onStartVoice)
            if hasText {
                iconButton("paperplane.fill", label: "发送消息", appearance: .accent, action: sendText)
            } else if showsCallButton {
                iconButton("phone.fill", label: "开始通话", appearance: .circular, action: onCall)
            }
        }
    }

    private var voiceCapsuleButton: some View {
        Button(action: onStartVoice) {
            Label("点击开始说话", systemImage: "mic.fill")
                .font(.system(size: metrics.textFontSize))
                .foregroundStyle(style.secondaryTextColor)
                .frame(maxWidth: .infinity, minHeight: metrics.controlDiameter)
                .contentShape(Capsule())
        }
        .buttonStyle(ComposerCapsuleButtonStyle(style: style))
        .accessibilityLabel("点击开始说话")
    }

    private var textField: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: metrics.textFontSize))
                    .foregroundStyle(style.placeholderColor)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text, axis: .vertical)
                .accessibilityIdentifier("message-composer-text-field")
                .focused($isFocused)
                .lineLimit(1...maximumLines)
                .font(.system(size: metrics.textFontSize))
                .foregroundStyle(style.textColor)
                .tint(style.accent)
        }
        .padding(.horizontal, metrics.fieldHorizontalPadding)
        .padding(.vertical, metrics.fieldVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: metrics.controlDiameter, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: metrics.fieldCornerRadius, style: .continuous)
                .fill(style.fieldBackground)
        )
        .shadow(color: style.shadowColor, radius: metrics.shadowRadius, y: metrics.shadowYOffset)
    }

    private var waveform: some View {
        ComposerWaveformBar(amplitudes: audioLevels, style: style)
    }

    private var actionBracketButton: some View {
        Text("录入动作")
            .font(.system(size: metrics.actionFontSize, weight: .medium))
            .foregroundStyle(isActionPressed ? style.buttonForeground : style.textColor)
            .frame(width: metrics.actionBracketDiameter, height: metrics.actionBracketDiameter)
            .background {
                Circle()
                    .fill(isActionPressed ? style.actionPressedBackground : style.fieldBackground)
                    .overlay(Circle().stroke(style.actionBorderColor, lineWidth: metrics.separatorThickness))
            }
            .scaleEffect(isActionPressed ? metrics.pressedActionScale : metrics.restingScale)
            .animation(.easeInOut(duration: metrics.interactionDuration), value: isActionPressed)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: metrics.longPressMinimumDuration, maximumDistance: metrics.longPressMaximumDistance, perform: {}) { pressing in
                isActionPressed = pressing
                onActionPressChanged?(pressing)
            }
            .accessibilityLabel("按住录入动作")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: metrics.statusSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: metrics.smallFontSize))
            Text(message).font(.system(size: metrics.smallFontSize))
        }
        .foregroundStyle(style.dangerColor)
        .padding(.horizontal, metrics.errorBannerHorizontalPadding)
        .padding(.vertical, metrics.errorBannerVerticalPadding)
        .background(Capsule().fill(style.fieldBackground))
        .fixedSize(horizontal: true, vertical: false)
        .padding(.bottom, metrics.errorBannerBottomPadding)
    }

    private func iconButton(
        _ symbol: String,
        label: String,
        appearance: ComposerIconButtonStyle.Appearance,
        action: @escaping () -> Void
    ) -> some View {
        ComposerIconButton(symbol: symbol, label: label, appearance: appearance, style: style, action: action)
    }

    private func setMode(_ newMode: InputMode) {
        mode = newMode
        onModeChange?(newMode)
    }

    private func sendText() {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        onSend(message)
        text = ""
    }

    private var metrics: ComponentDesignMetrics { .warmEmber }
}

private struct ComposerIconButton: View {
    let symbol: String
    let label: String
    let appearance: ComposerIconButtonStyle.Appearance
    let style: MessageComposer.Style
    let action: () -> Void

    var body: some View {
        Button {
            impact()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: ComponentDesignMetrics.warmEmber.iconFontSize, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(
                    width: ComponentDesignMetrics.warmEmber.controlDiameter,
                    height: ComponentDesignMetrics.warmEmber.controlDiameter
                )
                .background {
                    if appearance != .plain {
                        Circle()
                            .fill(background)
                            .frame(
                                width: ComponentDesignMetrics.warmEmber.controlBackgroundDiameter,
                                height: ComponentDesignMetrics.warmEmber.controlBackgroundDiameter
                            )
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(ComposerIconButtonStyle())
        .accessibilityLabel(label)
    }

    private var foreground: Color {
        switch appearance {
        case .plain: style.secondaryTextColor
        case .circular, .disabled: style.buttonForeground
        case .accent: style.barBackground
        }
    }

    private var background: Color {
        switch appearance {
        case .plain: ComponentDesignPalette.warmEmber.transparent
        case .circular: style.buttonBackground
        case .accent: style.accent
        case .disabled: style.disabledBackground
        }
    }

    private func impact() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private struct ComposerIconButtonStyle: ButtonStyle {
    enum Appearance: Equatable {
        case plain
        case circular
        case accent
        case disabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? ComponentDesignMetrics.warmEmber.pressedButtonScale
                    : ComponentDesignMetrics.warmEmber.restingScale
            )
            .opacity(
                configuration.isPressed
                    ? ComponentDesignMetrics.warmEmber.pressedButtonOpacity
                    : ComponentDesignMetrics.warmEmber.fullOpacity
            )
            .animation(
                .easeOut(duration: ComponentDesignMetrics.warmEmber.interactionDuration),
                value: configuration.isPressed
            )
    }
}

private struct ComposerCapsuleButtonStyle: ButtonStyle {
    let style: MessageComposer.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: ComponentDesignMetrics.warmEmber.fieldCornerRadius, style: .continuous)
                    .fill(style.fieldBackground)
            )
            .shadow(
                color: style.shadowColor,
                radius: ComponentDesignMetrics.warmEmber.shadowRadius,
                y: ComponentDesignMetrics.warmEmber.shadowYOffset
            )
            .scaleEffect(
                configuration.isPressed
                    ? ComponentDesignMetrics.warmEmber.pressedFieldScale
                    : ComponentDesignMetrics.warmEmber.restingScale
            )
            .animation(
                .easeOut(duration: ComponentDesignMetrics.warmEmber.interactionDuration),
                value: configuration.isPressed
            )
    }
}

#Preview("ZPing Message Composer") {
    struct PreviewHost: View {
        @State private var text = ""
        @State private var mode = MessageComposer.InputMode.text
        @State private var voiceState = MessageComposer.VoiceState.idle
        @State private var levels: [Float] = (0..<36).map { Float(($0 % 7) + 1) / 8 }

        var body: some View {
            VStack {
                Spacer()
                MessageComposer(
                    text: $text,
                    mode: $mode,
                    voiceState: $voiceState,
                    audioLevels: levels,
                    onSend: { _ in text = "" },
                    onStartVoice: { voiceState = .recording },
                    onStopVoice: { voiceState = .transcribing },
                    onCancelVoice: { voiceState = .idle },
                    onDirectSend: { voiceState = .transcribing },
                    onModeChange: { mode = $0 }
                )
            }
            .background(MessageComposer.Style.zping.barBackground)
            .preferredColorScheme(.dark)
        }
    }
    return PreviewHost().frame(width: 390, height: 280)
}
