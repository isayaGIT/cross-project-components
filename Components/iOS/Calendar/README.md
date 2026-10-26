# CalendarMonthView

A reusable SwiftUI month card for sticker-based daily memories. The month card owns the visual calendar surface; callers supply month data, theme tokens, optional custom SwiftUI regions, month-swipe handling, and day selection. Persistence and day-detail presentation remain host responsibilities.

```swift
CalendarMonthView(
    month: displayedMonth,
    days: [
        .init(date: displayedMonth, stickers: [
            .init(id: "me", image: Image("sticker-me")),
            .init(id: "partner", image: Image("sticker-partner"))
        ])
    ],
    dayCellStyle: .init(
        numberFont: .system(size: 10, weight: .regular),
        numberAlignment: .center
    ),
    onChangeMonth: { offset in
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    },
    onSelectDay: { date in
        // Open the selected day's records.
    }
)
```

## Composition and themes

- `CalendarMonthView` is the month-card container. `cardShape` accepts `AnyShape`; `headerImage`, `headerSeparator`, `weekdayBar`, `horizontalDayDivider`, and `verticalDayDivider` accept `AnyView` customization points.
- `CalendarDayCell` is an independent public view. Its `Style` controls day-number font, color, alignment, content alignment and spacing, padding, and optional custom background/overlay. The default day number is small and horizontally centered at the top of the cell, with stickers arranged below it. The cell uses a tall, stable footprint regardless of sticker count; up to two stickers are displayed per day. `Style.glassOpacity`, `glassTint`, and `glassBorderOpacity` tune the single glass surface without stacking multiple glass layers.
- `cellSpacing`, `cellCornerRadius`, and `usesGlassCells` tune the default glass cell appearance. `CalendarDayCell.Style` exposes glass opacity, tint, and edge-highlight opacity. A custom `Style.background` replaces that default background, allowing theme-specific shapes and materials.
- A horizontal swipe calls `onChangeMonth` with `-1` for the previous month and `1` for the next month. Hosts own the month state and can wrap the update in their preferred animation.
- `BorderConfiguration` retains line-style configuration for the outside border and standard divider families. The optional custom divider views are intended for custom paths, dashed lines, and other theme-specific artwork.

Keep date calculation, data persistence, and presentation of the selected day's records outside the view so the calendar can be reused by multiple themes and host applications.
