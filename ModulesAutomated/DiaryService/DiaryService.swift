import Foundation

public actor DiaryService {
    public static let scheduleHour = 23

    public static let reflectionSystemPrompt = """
你是一个温柔、细腻、善于共情的日记伙伴。你的任务是阅读用户当天的日记，并写一段真诚、自然、有温度的回应。
请注意：
1. 不要复述用户的日记内容，而是回应其中的情绪、感受和潜在需求。
2. 不要说教，不要给出过多建议；优先给予理解、陪伴和适度的鼓励。
3. 语言自然，像熟悉的朋友，不要使用生硬的模板化表达。
4. 如果日记内容很少，也要认真回应，不要凭空编造用户没有表达的经历。
5. 输出 JSON，字段为 toUser、private 和 sticker；没有合适的贴纸时 sticker 可以为空字符串。
"""

    public static let scheduledSystemPrompt = """
你是用户的日记伙伴。请根据用户当天的日记和近期对话，生成一段适合主动发送给用户的简短回应。
回应应自然、具体、克制，不要假装知道没有提供的信息，不要说教。
只输出 JSON，字段为 toUser、private 和 sticker；没有合适的贴纸时 sticker 可以为空字符串。
"""

    public enum ServiceError: Error, LocalizedError, Sendable {
        case invalidMonth(year: Int, month: Int)
        case unreadableEntry(String)
        case encoding(String)
        case io(String)
        case emptyReflection

        public var errorDescription: String? {
            switch self {
            case .invalidMonth(let year, let month):
                return "Invalid diary month: \(year)-\(month)"
            case .unreadableEntry(let path):
                return "Could not read diary entry at \(path)"
            case .encoding(let reason):
                return "Could not encode diary entry: \(reason)"
            case .io(let reason):
                return "Diary filesystem operation failed: \(reason)"
            case .emptyReflection:
                return "Reflection result must contain toUser or private content"
            }
        }
    }

    public typealias FileReader = @Sendable (URL) throws -> Data
    public typealias FileWriter = @Sendable (URL, Data) throws -> Void
    public typealias DirectoryCreator = @Sendable (URL) throws -> Void
    public typealias DirectoryLister = @Sendable (URL) throws -> [URL]
    public typealias DateProvider = @Sendable () -> Date

    private let rootDirectory: URL
    private let calendar: Calendar
    private let dateProvider: DateProvider
    private let fileReader: FileReader
    private let fileWriter: FileWriter
    private let directoryCreator: DirectoryCreator
    private let directoryLister: DirectoryLister
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootDirectory: URL,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current,
        dateProvider: @escaping DateProvider = { Date() },
        fileReader: @escaping FileReader = { try Data(contentsOf: $0) },
        fileWriter: @escaping FileWriter = { url, data in try data.write(to: url, options: .atomic) },
        directoryCreator: @escaping DirectoryCreator = { url in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        },
        directoryLister: @escaping DirectoryLister = { url in
            try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        }
    ) {
        self.rootDirectory = rootDirectory
        var configuredCalendar = calendar
        configuredCalendar.timeZone = timeZone
        self.calendar = configuredCalendar
        self.dateProvider = dateProvider
        self.fileReader = fileReader
        self.fileWriter = fileWriter
        self.directoryCreator = directoryCreator
        self.directoryLister = directoryLister
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.decoder = JSONDecoder()
    }

    /// Accepts the same shape-only validation as the Python implementation.
    /// An invalid or absent date resolves to the injected provider's local date.
    public func safeDate(_ dateString: String?) -> String {
        guard let dateString,
              dateString.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return currentDateString()
        }
        return dateString
    }

    public func diaryURL(for dateString: String?) -> URL {
        rootDirectory.appendingPathComponent(safeDate(dateString) + ".json", isDirectory: false)
    }

    public func emptyEntry(for dateString: String? = nil) -> DiaryEntry {
        DiaryEntry(date: safeDate(dateString))
    }

    /// Missing files and malformed JSON yield a default entry, as in the source service.
    public func readEntry(for dateString: String? = nil) -> DiaryEntry {
        let requestedDate = safeDate(dateString)
        let url = rootDirectory.appendingPathComponent(requestedDate + ".json", isDirectory: false)
        guard let data = try? fileReader(url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let object = raw as? [String: Any] else {
            return DiaryEntry(date: requestedDate)
        }
        let storedDate = object["date"] as? String
        let entryDate = safeDate((storedDate?.isEmpty == false) ? storedDate : requestedDate)
        let user = sectionObject(object["user"])
        let ai = sectionObject(object["ai"])
        let userSection = DiaryUserSection(
            content: user["content"] as? String ?? "",
            sticker: jsonValue(user["sticker"]) ?? .null,
            updatedAt: jsonValue(user["updatedAt"]) ?? .null,
            extra: user.filter { !["content", "sticker", "updatedAt"].contains($0.key) }.compactMapValues(jsonValue)
        )
        let aiSection = DiaryAISection(
            toUser: ai["toUser"] as? String ?? "",
            privateContent: ai["private"] as? String ?? "",
            sticker: jsonValue(ai["sticker"]) ?? .null,
            updatedAt: jsonValue(ai["updatedAt"]) ?? .null,
            scheduledAt: jsonValue(ai["scheduledAt"]) ?? .null,
            extra: ai.filter { !["toUser", "private", "sticker", "updatedAt", "scheduledAt"].contains($0.key) }.compactMapValues(jsonValue)
        )
        let extras = object.filter { !["date", "user", "ai", "tags"].contains($0.key) }.compactMapValues(jsonValue)
        return DiaryEntry(
            date: entryDate,
            user: userSection,
            ai: aiSection,
            tags: jsonValue(object["tags"]) ?? .array([]),
            extra: extras
        )
    }

    public func writeEntry(_ entry: DiaryEntry, for dateString: String? = nil) throws {
        let date = safeDate(dateString ?? entry.date)
        let url = rootDirectory.appendingPathComponent(date + ".json", isDirectory: false)
        var normalized = entry
        normalized.date = date
        do {
            try directoryCreator(rootDirectory)
        } catch {
            throw ServiceError.io(error.localizedDescription)
        }
        let data: Data
        do {
            data = try encoder.encode(normalized)
        } catch {
            throw ServiceError.encoding(error.localizedDescription)
        }
        do {
            try fileWriter(url, data)
        } catch {
            throw ServiceError.io(error.localizedDescription)
        }
    }

    public func daySummary(_ entry: DiaryEntry, full: Bool = false) -> DiaryDaySummary {
        let userContent = entry.user.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let aiToUser = entry.ai.toUser.trimmingCharacters(in: .whitespacesAndNewlines)
        return DiaryDaySummary(
            date: entry.date,
            userSticker: entry.user.sticker,
            aiSticker: entry.ai.sticker,
            hasUser: !userContent.isEmpty,
            hasAi: !aiToUser.isEmpty,
            userPreview: String(userContent.unicodeScalars.prefix(40).map(Character.init)),
            userContent: full ? userContent : nil,
            aiToUser: full ? aiToUser : nil,
            aiPrivate: full ? entry.ai.privateContent.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }

    /// Lists filenames descending before validating date-shaped stems, matching Python slicing order.
    public func listIndex(limit: Int = 365) -> [DiaryDaySummary] {
        guard let urls = try? directoryLister(rootDirectory) else { return [] }
        let sorted = urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        let limited: [URL]
        if limit >= 0 {
            limited = Array(sorted.prefix(limit))
        } else {
            let end = max(0, sorted.count + limit)
            limited = Array(sorted.prefix(end))
        }
        var summaries: [DiaryDaySummary] = []
        for url in limited {
            let stem = url.deletingPathExtension().lastPathComponent
            guard stem.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { continue }
            do {
                let data = try fileReader(url)
                let raw = try JSONSerialization.jsonObject(with: data)
                guard let object = raw as? [String: Any] else {
                    summaries.append(fallbackSummary(date: stem))
                    continue
                }
                let userRaw = object["user"]
                let aiRaw = object["ai"]
                if isPythonTruthy(userRaw), !(userRaw is [String: Any]) {
                    summaries.append(fallbackSummary(date: stem))
                    continue
                }
                if isPythonTruthy(aiRaw), !(aiRaw is [String: Any]) {
                    summaries.append(fallbackSummary(date: stem))
                    continue
                }
                let entry = entryFromRaw(object, fallbackDate: stem)
                summaries.append(daySummary(entry))
            } catch {
                summaries.append(fallbackSummary(date: stem))
            }
        }
        return summaries
    }

    public func monthCalendar(year: Int, month: Int) throws -> DiaryMonthCalendar {
        guard (1...9999).contains(year), (1...12).contains(month) else {
            throw ServiceError.invalidMonth(year: year, month: month)
        }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            throw ServiceError.invalidMonth(year: year, month: month)
        }
        var days: [String: DiaryDaySummary] = [:]
        for day in range {
            let date = String(format: "%04d-%02d-%02d", year, month, day)
            days[date] = daySummary(readEntry(for: date), full: true)
        }
        return DiaryMonthCalendar(year: year, month: month, days: days)
    }

    public func buildReflectionPrompt(
        entry: DiaryEntry,
        recentDialog: String = "",
        stickerBlock: String = ""
    ) -> String {
        let date = entry.date.isEmpty ? currentDateString() : entry.date
        let userContent = entry.user.content.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = ["日期：\(date)"]
        parts.append("用户日记：\n\(userContent.isEmpty ? "（用户今天还没有写日记）" : userContent)")
        if !recentDialog.isEmpty {
            let recent = String(recentDialog.unicodeScalars.suffix(2000).map(Character.init))
            parts.append("近期对话（供理解上下文，最多保留末尾 2000 个 Unicode 字符）：\n\(recent)")
        }
        if !stickerBlock.isEmpty {
            parts.append(stickerBlock)
        }
        parts.append("请根据以上内容，生成自然、真诚且不过度推断的日记回应。只输出 JSON。")
        return parts.joined(separator: "\n\n")
    }

    @discardableResult
    public func applyReflectionResult(
        to entry: inout DiaryEntry,
        parsed: [String: DiaryJSONValue],
        scheduled: Bool = false,
        now: Date? = nil
    ) throws -> DiaryEntry {
        let primaryRaw = parsed["toUser"]?.stringValue
        let alternateRaw = parsed["to_user"]?.stringValue
        let selectedRaw = (primaryRaw.map { !$0.isEmpty } == true) ? primaryRaw : alternateRaw
        let toUser = (selectedRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let privateContent = (parsed["private"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let stickerString = (parsed["sticker"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !toUser.isEmpty || !privateContent.isEmpty else {
            throw ServiceError.emptyReflection
        }
        let timestamp = Int64((now ?? dateProvider()).timeIntervalSince1970 * 1000)
        entry.ai.toUser = toUser
        entry.ai.privateContent = privateContent
        if !stickerString.isEmpty {
            entry.ai.sticker = .string(stickerString)
        }
        entry.ai.updatedAt = .integer(timestamp)
        if scheduled {
            entry.ai.scheduledAt = .integer(timestamp)
        }
        return entry
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: dateProvider())
    }

    private func sectionObject(_ value: Any?) -> [String: Any] {
        guard let dictionary = value as? [String: Any] else { return [:] }
        return dictionary
    }

    private func jsonValue(_ value: Any?) -> DiaryJSONValue? {
        guard let value else { return nil }
        if value is NSNull { return .null }
        if let value = value as? String { return .string(value) }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            let double = value.doubleValue
            if double.isFinite, double.rounded(.towardZero) == double, double >= Double(Int64.min), double <= Double(Int64.max) {
                return .integer(value.int64Value)
            }
            return .number(double)
        }
        if let value = value as? [Any] {
            return .array(value.compactMap { jsonValue($0) })
        }
        if let value = value as? [String: Any] {
            return .object(value.compactMapValues(jsonValue))
        }
        return nil
    }

    private func entryFromRaw(_ object: [String: Any], fallbackDate: String) -> DiaryEntry {
        let user = sectionObject(object["user"])
        let ai = sectionObject(object["ai"])
        let storedDate = object["date"] as? String
        let date = safeDate((storedDate?.isEmpty == false) ? storedDate : fallbackDate)
        return DiaryEntry(
            date: date,
            user: DiaryUserSection(
                content: user["content"] as? String ?? "",
                sticker: jsonValue(user["sticker"]) ?? .null,
                updatedAt: jsonValue(user["updatedAt"]) ?? .null,
                extra: user.filter { !["content", "sticker", "updatedAt"].contains($0.key) }.compactMapValues(jsonValue)
            ),
            ai: DiaryAISection(
                toUser: ai["toUser"] as? String ?? "",
                privateContent: ai["private"] as? String ?? "",
                sticker: jsonValue(ai["sticker"]) ?? .null,
                updatedAt: jsonValue(ai["updatedAt"]) ?? .null,
                scheduledAt: jsonValue(ai["scheduledAt"]) ?? .null,
                extra: ai.filter { !["toUser", "private", "sticker", "updatedAt", "scheduledAt"].contains($0.key) }.compactMapValues(jsonValue)
            ),
            tags: jsonValue(object["tags"]) ?? .array([]),
            extra: object.filter { !["date", "user", "ai", "tags"].contains($0.key) }.compactMapValues(jsonValue)
        )
    }

    private func summaryFromRaw(_ object: [String: Any], date: String, full: Bool = false) -> DiaryDaySummary {
        daySummary(entryFromRaw(object, fallbackDate: date), full: full)
    }

    private func fallbackSummary(date: String) -> DiaryDaySummary {
        DiaryDaySummary(date: date, userPreview: "", hasAi: false)
    }

    private func isPythonTruthy(_ value: Any?) -> Bool {
        guard let value else { return false }
        if value is NSNull { return false }
        if let value = value as? String { return !value.isEmpty }
        if let value = value as? NSNumber { return value.doubleValue != 0 }
        if let value = value as? [Any] { return !value.isEmpty }
        if let value = value as? [String: Any] { return !value.isEmpty }
        return true
    }
}

import CoreFoundation
