import Foundation

public enum ScheduleTime {
    /// Matches the source's date-shape validation: a matching string is retained
    /// without additional calendar-date validation.
    public static func safeDate(_ input: String?, now: Date = Date(), calendar: Calendar = .current) -> String {
        if let input = input, input.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return input
        }
        var calendar = calendar
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day else {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: now)
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Converts a clock string to minutes after midnight. The calculation
    /// intentionally mirrors the Python implementation's total-minute bounds.
    public static func minutes(_ value: String?) -> Int? {
        guard let value = value else { return nil }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let result = hour * 60 + minute
        guard result >= 0, result < 1440 else { return nil }
        return result
    }

    public static func clock(_ totalMinutes: Int) -> String {
        let normalized = ((totalMinutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

    /// Python's datetime.weekday convention: Monday = 0, Sunday = 6.
    public static func weekday(dateString: String, calendar: Calendar = .current) -> Int? {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var calendar = calendar
        calendar.timeZone = calendar.timeZone
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let weekday = calendar.dateComponents([.weekday], from: date).weekday else { return nil }
        return (weekday + 5) % 7
    }

    public static func blocksForDate(template: [String: Any], weekday: Int) -> [[String: Any]] {
        let key = weekday >= 5 ? "weekend" : "weekday"
        return ScheduleJSON.dictionaries(template[key]) ?? ScheduleJSON.dictionaries(template["weekday"]) ?? []
    }

    public static func isInSleep(minute: Int, sleep: [String: Any]?) -> Bool {
        guard let sleep = sleep, ScheduleJSON.bool(sleep["enabled"], default: false),
              let bedtime = minutes(ScheduleJSON.string(sleep["bedtime"])),
              let wakeTime = minutes(ScheduleJSON.string(sleep["wakeTime"])),
              bedtime != wakeTime else { return false }
        if bedtime < wakeTime { return minute >= bedtime && minute < wakeTime }
        return minute >= bedtime || minute < wakeTime
    }

    public static func blockOverlapsSleep(_ block: [String: Any], sleep: [String: Any]?) -> Bool {
        guard let start = minutes(ScheduleJSON.string(block["start"])),
              let end = minutes(ScheduleJSON.string(block["end"])),
              let sleep = sleep, ScheduleJSON.bool(sleep["enabled"], default: false),
              let bedtime = minutes(ScheduleJSON.string(sleep["bedtime"])),
              let wakeTime = minutes(ScheduleJSON.string(sleep["wakeTime"])),
              bedtime != wakeTime else { return false }

        let blockRanges: [(Int, Int)] = start < end ? [(start, end)] : [(start, 1440), (0, end)]
        let sleepRanges: [(Int, Int)] = bedtime < wakeTime ? [(bedtime, wakeTime)] : [(bedtime, 1440), (0, wakeTime)]
        return blockRanges.contains { a in
            sleepRanges.contains { b in max(a.0, b.0) < min(a.1, b.1) }
        }
    }

    public static func filterSleepBlocks(_ blocks: [[String: Any]], sleep: [String: Any]?) -> [[String: Any]] {
        blocks.filter { !blockOverlapsSleep($0, sleep: sleep) }
    }

    public static func currentBlock(blocks: [[String: Any]], minute: Int) -> (index: Int, block: [String: Any]?) {
        for (index, block) in blocks.enumerated() {
            guard let start = minutes(ScheduleJSON.string(block["start"])),
                  let end = minutes(ScheduleJSON.string(block["end"])) else { continue }
            let matches: Bool
            if start < end {
                matches = minute >= start && minute < end
            } else {
                matches = minute >= start || minute < end
            }
            if matches { return (index, block) }
        }
        return (-1, nil)
    }

    public static func currentMinute(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    public static func generatedAtMilliseconds(now: Date = Date()) -> Int64 {
        Int64((now.timeIntervalSince1970 * 1000.0).rounded(.down))
    }
}
