import SwiftUI
import LineDashed

/// A configurable monthly calendar whose day cells are twice as tall as they are wide.
/// It deliberately owns presentation only; callers supply sticker images and tap handling.
public struct CalendarMonthView: View {
    /// Experimental relief treatment for the month label. This is optical shading, not a raster texture.
    public enum MonthTextRelief {
        case flat
        case embossed
        case engraved
    }
    public struct Day: Identifiable {
        public let date: Date
        public var stickers: [CalendarSticker]
        public var id: Date { Calendar.current.startOfDay(for: date) }

        public init(date: Date, stickers: [CalendarSticker] = []) {
            self.date = date
            self.stickers = Array(stickers.prefix(2))
        }
    }

    public struct LineStyle {
        public enum Pattern {
            case solid
            case dashed(DashedLineConfiguration)
        }

        public var color: Color
        public var weight: CGFloat
        public var pattern: Pattern

        public init(color: Color = .primary.opacity(0.16), weight: CGFloat = 1, pattern: Pattern = .solid) {
            self.color = color
            self.weight = weight.isFinite ? max(0, weight) : 0
            self.pattern = pattern
        }


    }

    public struct BorderConfiguration {
        public var outer: LineStyle
        public var weekdayDividers: LineStyle
        public var dayDividers: LineStyle
        public var weekDividers: LineStyle
        /// Positive values expand the outer border path; negative values inset it.
        public var outerOffset: CGFloat

        public init(
            outer: LineStyle = .init(color: .primary.opacity(0.22), weight: 1),
            weekdayDividers: LineStyle = .init(),
            dayDividers: LineStyle = .init(),
            weekDividers: LineStyle = .init(),
            outerOffset: CGFloat = 0
        ) {
            self.outer = outer
            self.weekdayDividers = weekdayDividers
            self.dayDividers = dayDividers
            self.weekDividers = weekDividers
            self.outerOffset = outerOffset.isFinite ? outerOffset : 0
        }

        public static let standard = BorderConfiguration()
    }

    private let month: Date
    private let calendar: Calendar
    private let locale: Locale
    private let weekdaySymbols: [String]
    private let days: [Day]
    private let monthColor: Color
    private let yearColor: Color
    private let weekdayColor: Color
    private let dayNumberColor: Color
    private let monthFont: Font
    private let monthTextRelief: MonthTextRelief
    private let yearFont: Font
    private let weekdayFont: Font
    private let dayNumberFont: Font
    private let borders: BorderConfiguration
    private let background: Color
    private let stickerSize: CGFloat
    private let onSelectDay: ((Date) -> Void)?
    private let cardShape: AnyShape
    private let headerImage: AnyView
    private let headerSeparator: AnyView
    private let weekdayBar: AnyView?
    private let horizontalDayDivider: AnyView?
    private let verticalDayDivider: AnyView?
    private let cellSpacing: CGFloat
    private let cellCornerRadius: CGFloat
    private let usesGlassCells: Bool
    private let onChangeMonth: ((Int) -> Void)?
    private let dayCellStyle: CalendarDayCell.Style
    private let dayCellBackground: ((Int) -> AnyView)?
    private let onTapHeaderImage: (() -> Void)?

    public init(
        month: Date,
        days: [Day] = [],
        calendar: Calendar = .current,
        locale: Locale = .current,
        weekdaySymbols: [String]? = nil,
        monthColor: Color = .primary,
        yearColor: Color = .secondary,
        weekdayColor: Color = .secondary,
        dayNumberColor: Color = .primary,
        monthFont: Font = .system(size: 24, weight: .regular, design: .serif),
        monthTextRelief: MonthTextRelief = .flat,
        yearFont: Font = .system(size: 14, weight: .regular, design: .serif),
        weekdayFont: Font = .system(size: 11, weight: .medium, design: .default),
        dayNumberFont: Font = .system(size: 13, weight: .regular, design: .default),
        borders: BorderConfiguration = .standard,
        background: Color = .clear,
        stickerSize: CGFloat = 24,
        cardShape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 28, style: .continuous)),
        headerImage: AnyView = AnyView(
            LinearGradient(colors: [Color.white.opacity(0.35), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .ultraLight))
                        .foregroundStyle(.primary.opacity(0.12))
                        .padding(18)
                }
        ),
        headerSeparator: AnyView = AnyView(Rectangle().fill(.primary.opacity(0.10)).frame(height: 1)),
        weekdayBar: AnyView? = nil,
        horizontalDayDivider: AnyView? = nil,
        verticalDayDivider: AnyView? = nil,
        cellSpacing: CGFloat = 5,
        cellCornerRadius: CGFloat = 9,
        usesGlassCells: Bool = true,
        dayCellStyle: CalendarDayCell.Style? = nil,
        dayCellBackground: ((Int) -> AnyView)? = nil,
        onTapHeaderImage: (() -> Void)? = nil,
        onChangeMonth: ((Int) -> Void)? = nil,
        onSelectDay: ((Date) -> Void)? = nil
    ) {
        self.month = month
        self.days = days
        self.calendar = calendar
        self.locale = locale
        self.weekdaySymbols = weekdaySymbols ?? calendar.veryShortStandaloneWeekdaySymbols
        self.monthColor = monthColor
        self.yearColor = yearColor
        self.weekdayColor = weekdayColor
        self.dayNumberColor = dayNumberColor
        self.monthFont = monthFont
        self.monthTextRelief = monthTextRelief
        self.yearFont = yearFont
        self.weekdayFont = weekdayFont
        self.dayNumberFont = dayNumberFont
        self.borders = borders
        self.background = background
        self.stickerSize = stickerSize.isFinite ? max(8, stickerSize) : 24
        self.onSelectDay = onSelectDay
        self.cardShape = cardShape
        self.headerImage = headerImage
        self.headerSeparator = headerSeparator
        self.weekdayBar = weekdayBar
        self.horizontalDayDivider = horizontalDayDivider
        self.verticalDayDivider = verticalDayDivider
        self.cellSpacing = cellSpacing.isFinite ? max(0, cellSpacing) : 5
        self.cellCornerRadius = cellCornerRadius.isFinite ? max(0, cellCornerRadius) : 9
        self.usesGlassCells = usesGlassCells
        self.dayCellStyle = dayCellStyle ?? .init(numberFont: dayNumberFont, numberColor: dayNumberColor)
        self.dayCellBackground = dayCellBackground
        self.onTapHeaderImage = onTapHeaderImage
        self.onChangeMonth = onChangeMonth
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingBlankCount: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekCount: Int {
        (leadingBlankCount + daysInMonth + 6) / 7
    }

    private var dayByNumber: [Int: Day] {
        Dictionary(days.compactMap { day -> (Int, Day)? in
            guard calendar.isDate(day.date, equalTo: monthStart, toGranularity: .month) else { return nil }
            return (calendar.component(.day, from: day.date), day)
        }, uniquingKeysWith: { _, latest in latest })
    }

    private var localizedWeekdays: [String] {
        let symbols = weekdaySymbols
        guard symbols.count == 7 else { return Array(["S", "M", "T", "W", "T", "F", "S"]) }
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onTapHeaderImage?() } label: {
                headerImage
                    .frame(height: 132)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(month.formatted(.dateTime.month(.wide).locale(locale)))
                            .font(monthFont)
                            .foregroundStyle(monthColor)
                            .modifier(MonthTextReliefModifier(style: monthTextRelief, color: monthColor))
                        Text(String(calendar.component(.year, from: month)))
                            .font(yearFont)
                            .foregroundStyle(yearColor)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 13)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑日历 Header Image")

            headerSeparator
                .frame(maxWidth: .infinity)

            VStack(spacing: cellSpacing) {
                if let weekdayBar {
                    weekdayBar
                } else {
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(localizedWeekdays.enumerated()), id: \.offset) { _, weekday in
                            Text(weekday.uppercased())
                                .font(weekdayFont)
                                .tracking(0.4)
                                .foregroundStyle(weekdayColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 25)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7), spacing: cellSpacing) {
                    ForEach(0..<(weekCount * 7), id: \.self) { slot in
                        let dayNumber = slot - leadingBlankCount + 1
                        if dayNumber > 0 && dayNumber <= daysInMonth,
                           let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) {
                            CalendarDayCell(
                                dayNumber: dayNumber,
                                stickers: dayByNumber[dayNumber]?.stickers ?? [],
                                style: styleForDay(dayNumber),
                                stickerSize: stickerSize,
                                usesGlass: usesGlassCells,
                                cornerRadius: cellCornerRadius,
                                onTap: { onSelectDay?(date) }
                            )
                        } else {
                            Color.clear
                                .aspectRatio(0.52, contentMode: .fit)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .overlay {
                    CalendarCellDividers(
                        weekCount: weekCount,
                        horizontal: horizontalDayDivider,
                        vertical: verticalDayDivider
                    )
                    .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 7)
            .padding(.bottom, 14)
        }
        .background(.thinMaterial, in: cardShape)
        .clipShape(cardShape)
        .overlay {
            cardShape.fill(Color.white.opacity(0.02))
                .allowsHitTesting(false)
        }
        .overlay(cardShape.stroke(.white.opacity(0.10), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.07), radius: 24, x: 0, y: 12)
        .contentShape(cardShape)
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > 55,
                          abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    onChangeMonth?(value.translation.width < 0 ? 1 : -1)
                }
        )
        .accessibilityAction(named: Text("下个月")) { onChangeMonth?(1) }
        .accessibilityAction(named: Text("上个月")) { onChangeMonth?(-1) }
    }

    private func styleForDay(_ dayNumber: Int) -> CalendarDayCell.Style {
        guard let customBackground = dayCellBackground?(dayNumber) else { return dayCellStyle }
        var style = dayCellStyle
        style.background = customBackground
        return style
    }

}

/// Sticker image with optional cut-paper outline and a subtle lifted shadow.
public struct CalendarSticker: Identifiable {
    public let id: AnyHashable
    public let image: Image
    public var outlineColor: Color?
    public var outlineWidth: CGFloat
    public var shadowOpacity: CGFloat

    public init(
        id: AnyHashable = UUID(),
        image: Image,
        outlineColor: Color? = .white,
        outlineWidth: CGFloat = 2.5,
        shadowOpacity: CGFloat = 0.16
    ) {
        self.id = id
        self.image = image
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth.isFinite ? max(0, outlineWidth) : 0
        self.shadowOpacity = shadowOpacity.isFinite ? min(1, max(0, shadowOpacity)) : 0.16
    }
}

public struct CalendarStickerView: View {
    public let sticker: CalendarSticker
    public let size: CGFloat

    public init(sticker: CalendarSticker, size: CGFloat = 24) {
        self.sticker = sticker
        self.size = size.isFinite ? max(8, size) : 24
    }

    public var body: some View {
        SimulatedSticker(backToOriginal: true) {
            sticker.image
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

private struct CalendarDayPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? -1.2 : 0))
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.28), value: configuration.isPressed)
    }
}

private struct CalendarCellDividers: View {
    let weekCount: Int
    let horizontal: AnyView?
    let vertical: AnyView?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let horizontal {
                    VStack(spacing: 0) {
                        ForEach(1..<max(1, weekCount), id: \.self) { _ in
                            horizontal.frame(maxWidth: .infinity)
                            Spacer(minLength: 0)
                        }
                    }
                }
                if let vertical {
                    HStack(spacing: 0) {
                        ForEach(1..<7, id: \.self) { _ in
                            Spacer(minLength: 0)
                            vertical.frame(maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct MonthTextReliefModifier: ViewModifier {
    let style: CalendarMonthView.MonthTextRelief
    let color: Color

    func body(content: Content) -> some View {
        switch style {
        case .flat:
            content
        case .embossed:
            content
                .shadow(color: .white.opacity(0.72), radius: 0.55, x: -0.7, y: -0.8)
                .shadow(color: .black.opacity(0.19), radius: 0.65, x: 0.8, y: 1.0)
        case .engraved:
            content
                .shadow(color: .black.opacity(0.24), radius: 0.45, x: -0.65, y: -0.7)
                .shadow(color: .white.opacity(0.78), radius: 0.6, x: 0.7, y: 0.85)
        }
    }
}
