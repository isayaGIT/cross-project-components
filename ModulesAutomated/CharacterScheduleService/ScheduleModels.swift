import Foundation

/// Shared JSON-compatible schedule types and default configuration.
/// Dictionaries are intentional: the Python implementation accepts arbitrary
/// JSON fields, and callers may have fields that this subsystem does not own.
public enum ScheduleJSON {
    public static func string(_ value: Any?) -> String? {
        guard let value = value, !(value is NSNull) else { return nil }
        if let value = value as? String { return value }
        if let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() {
            return value.boolValue ? "true" : "false"
        }
        return String(describing: value)
    }

    public static func bool(_ value: Any?, default fallback: Bool = false) -> Bool {
        guard let value = value, !(value is NSNull) else { return fallback }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "on": return true
            case "false", "0", "no", "off", "": return false
            default: return fallback
            }
        }
        return fallback
    }

    public static func integer(_ value: Any?, default fallback: Int = 0) -> Int {
        guard let value = value else { return fallback }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let result = Int(string) { return result }
        return fallback
    }

    public static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    public static func dictionaries(_ value: Any?) -> [[String: Any]]? {
        guard let values = value as? [Any] else { return nil }
        return values.compactMap { $0 as? [String: Any] }
    }

    public static func jsonData(_ value: Any, prettyPrinted: Bool = true) throws -> Data {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw ScheduleServiceError.invalidJSON("Value is not a valid JSON object")
        }
        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted { options.insert(.prettyPrinted) }
        if #available(macOS 10.13, iOS 11.0, *) { options.insert(.sortedKeys) }
        return try JSONSerialization.data(withJSONObject: value, options: options)
    }

    public static func parseObject(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

public enum ScheduleServiceError: Error, LocalizedError {
    case invalidJSON(String)
    case invalidConfiguration(String)
    case persistence(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let message): return "Invalid schedule JSON: \(message)"
        case .invalidConfiguration(let message): return "Invalid schedule configuration: \(message)"
        case .persistence(let message): return "Schedule persistence failed: \(message)"
        }
    }
}

public enum ScheduleSleepState {
    public static let awake = "awake"
    public static let preSleep = "pre_sleep"
    public static let sleeping = "sleeping"
}

public struct ScheduleStoragePaths {
    public let templateURL: URL
    public let dailyDirectoryURL: URL
    public let stateURL: URL

    public init(templateURL: URL, dailyDirectoryURL: URL, stateURL: URL) {
        self.templateURL = templateURL
        self.dailyDirectoryURL = dailyDirectoryURL
        self.stateURL = stateURL
    }
}

public enum ScheduleDefaults {
    public static let generationSystemPrompt = """
你是角色的日程生成器。根据角色设定、生活习惯和日程模板，生成自然、可信、具体的当天日程。只输出 JSON，不要输出 Markdown 或额外解释。保留合理的空档和休息时间，活动安排应符合时间顺序和日常生活逻辑。
"""

    public static let template: [String: Any] = [
        "enabled": true,
        "timezone": "Asia/Shanghai",
        "location": "温泉小镇",
        "narrativeStyle": "dense",
        "weekday": [
            ["start": "07:30", "end": "08:30", "tag": "morning", "label": "起床洗漱、吃早餐", "busy": false],
            ["start": "08:30", "end": "12:00", "tag": "work", "label": "上午的工作和日常安排", "busy": true],
            ["start": "12:00", "end": "13:30", "tag": "lunch", "label": "午餐和午休", "busy": false],
            ["start": "13:30", "end": "18:00", "tag": "work", "label": "下午的工作和日常安排", "busy": true],
            ["start": "18:00", "end": "20:00", "tag": "evening", "label": "晚餐、散步或放松", "busy": false],
            ["start": "20:00", "end": "23:00", "tag": "leisure", "label": "个人时间", "busy": false]
        ],
        "weekend": [
            ["start": "09:00", "end": "10:00", "tag": "morning", "label": "睡到自然醒、吃早餐", "busy": false],
            ["start": "10:00", "end": "12:30", "tag": "outing", "label": "出门逛逛或处理杂事", "busy": false],
            ["start": "12:30", "end": "14:00", "tag": "lunch", "label": "午餐和休息", "busy": false],
            ["start": "14:00", "end": "18:00", "tag": "leisure", "label": "自由活动", "busy": false],
            ["start": "18:00", "end": "20:00", "tag": "evening", "label": "晚餐和散步", "busy": false],
            ["start": "20:00", "end": "23:00", "tag": "leisure", "label": "个人时间", "busy": false]
        ],
        "gapNotes": ["空档时间可以休息、处理小事或回复消息。", "活动不必排满全天，保留自然的生活节奏。"],
        "sleep": ["bedtime": "23:00", "wakeTime": "07:30", "enabled": true]
    ]
}

public struct ResolvedSchedule {
    public let template: [String: Any]
    public let daily: [String: Any]?
    public let state: [String: Any]
    public let promptBlock: String

    public init(template: [String: Any], daily: [String: Any]?, state: [String: Any], promptBlock: String) {
        self.template = template
        self.daily = daily
        self.state = state
        self.promptBlock = promptBlock
    }
}

public struct ScheduleGenerationOptions {
    public var force: Bool
    public var dateString: String?
    public var now: Date
    public var calendar: Calendar
    public var sleepState: String
    public var maxInspirationQueries: Int
    public var inspirationMode: String
    public var lifestyleContext: String
    public var personaText: String

    public init(
        force: Bool = false,
        dateString: String? = nil,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        sleepState: String = ScheduleSleepState.awake,
        maxInspirationQueries: Int = 2,
        inspirationMode: String = "xiaohongshu",
        lifestyleContext: String = "",
        personaText: String = ""
    ) {
        self.force = force
        self.dateString = dateString
        self.now = now
        self.calendar = calendar
        self.sleepState = sleepState
        self.maxInspirationQueries = max(0, maxInspirationQueries)
        self.inspirationMode = inspirationMode
        self.lifestyleContext = lifestyleContext
        self.personaText = personaText
    }
}

import CoreFoundation
