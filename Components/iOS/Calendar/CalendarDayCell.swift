import SwiftUI

/// One independently themeable day cell used by `CalendarMonthView`.
/// Its footprint is stable whether or not stickers are present.
public struct CalendarDayCell: View {
    public struct Style {
        public var numberFont: Font
        public var numberColor: Color
        public var numberAlignment: Alignment
        public var contentAlignment: HorizontalAlignment
        public var contentSpacing: CGFloat
        public var numberPadding: EdgeInsets
        /// Opacity applied to the single system glass layer (0...1).
        public var glassOpacity: CGFloat
        /// Optional tint over the glass surface; clear keeps the native material color.
        public var glassTint: Color
        /// Subtle edge highlight opacity (0...1).
        public var glassBorderOpacity: CGFloat
        public var background: AnyView?
        public var overlay: AnyView?

        public init(
            numberFont: Font = .system(size: 10, weight: .regular, design: .default),
            numberColor: Color = .primary.opacity(0.82),
            numberAlignment: Alignment = .center,
            contentAlignment: HorizontalAlignment = .center,
            contentSpacing: CGFloat = 3,
            numberPadding: EdgeInsets = EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0),
            glassOpacity: CGFloat = 0.72,
            glassTint: Color = .clear,
            glassBorderOpacity: CGFloat = 0.13,
            background: AnyView? = nil,
            overlay: AnyView? = nil
        ) {
            self.numberFont = numberFont
            self.numberColor = numberColor
            self.numberAlignment = numberAlignment
            self.contentAlignment = contentAlignment
            self.contentSpacing = contentSpacing.isFinite ? max(0, contentSpacing) : 3
            self.numberPadding = numberPadding
            self.glassOpacity = glassOpacity.isFinite ? min(1, max(0, glassOpacity)) : 0.72
            self.glassTint = glassTint
            self.glassBorderOpacity = glassBorderOpacity.isFinite ? min(1, max(0, glassBorderOpacity)) : 0.13
            self.background = background
            self.overlay = overlay
        }
    }

    public let dayNumber: Int
    public let stickers: [CalendarSticker]
    public var style: Style
    public var stickerSize: CGFloat
    public var usesGlass: Bool
    public var cornerRadius: CGFloat
    public var onTap: (() -> Void)?

    public init(
        dayNumber: Int,
        stickers: [CalendarSticker] = [],
        style: Style = .init(),
        stickerSize: CGFloat = 24,
        usesGlass: Bool = true,
        cornerRadius: CGFloat = 9,
        onTap: (() -> Void)? = nil
    ) {
        self.dayNumber = dayNumber
        self.stickers = Array(stickers.prefix(2))
        self.style = style
        self.stickerSize = stickerSize.isFinite ? max(8, stickerSize) : 24
        self.usesGlass = usesGlass
        self.cornerRadius = cornerRadius.isFinite ? max(0, cornerRadius) : 9
        self.onTap = onTap
    }

    public var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: style.contentAlignment, spacing: style.contentSpacing) {
                Text(String(dayNumber))
                    .font(style.numberFont)
                    .foregroundStyle(style.numberColor)
                    .frame(maxWidth: .infinity, alignment: style.numberAlignment)
                    .padding(style.numberPadding)

                ForEach(stickers) { sticker in
                    CalendarStickerView(sticker: sticker, size: stickerSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 3)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .aspectRatio(0.52, contentMode: .fit)
            .background {
                if let custom = style.background {
                    custom
                } else if usesGlass {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(max(style.glassOpacity, 0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(style.glassTint)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(.white.opacity(style.glassBorderOpacity), lineWidth: 0.6)
                        }
                }
            }
            .overlay { style.overlay }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(CalendarDayCellPressStyle())
        .accessibilityLabel("日期 \(dayNumber)")
        .accessibilityHint("查看这一天的记录")
    }
}

private struct CalendarDayCellPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.16), value: configuration.isPressed)
    }
}
