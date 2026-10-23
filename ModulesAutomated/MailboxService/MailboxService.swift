import Foundation

public enum MailboxServiceError: Error, LocalizedError, Sendable {
    case invalidRecord(String)
    case unsupportedJSONValue(String)
    case filesystem(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRecord(let message): return message
        case .unsupportedJSONValue(let type): return "Unsupported mailbox JSON value: \(type)"
        case .filesystem(let message): return "Mailbox storage error: \(message)"
        }
    }
}

public enum MailboxFolder: String, Sendable {
    case all
    case inbox
    case outbox
    case unread
}

public enum MailboxService {
    /// Ordered exactly as in cloud/services/mailbox.py's COVER_TONES tuple.
    public static let coverToneOptions = ["warm", "cool", "dusk", "mint", "rose", "ink"]
    public static let coverTones: Set<String> = Set(coverToneOptions)
    public static let replySystemPrompt = MailboxPrompts.replySystem
    public static let proactiveSystemPrompt = MailboxPrompts.proactiveSystem

    public static func isSafeID(_ value: String?) -> Bool {
        guard let value, !value.isEmpty, value.count >= 6, value.count <= 64 else { return false }
        return value.range(of: "^[a-zA-Z0-9_-]{6,64}$", options: .regularExpression) != nil
    }

    public static func normalizedTone(_ value: String?) -> String {
        let tone = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return coverTones.contains(tone) ? tone : "warm"
    }

    public static func applyAIParsed(_ parsed: MailboxRecord, replyTo: String? = nil) -> MailboxRecord {
        let rawSubject = (parsed["subject"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyValue = parsed["body"].flatMap { $0.isTruthy ? $0 : nil } ?? parsed["content"].flatMap { $0.isTruthy ? $0 : nil }
        let body = (bodyValue?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let sticker = (parsed["sticker"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let toneValue = parsed["coverTone"].flatMap { $0.isTruthy ? $0.stringValue : nil }
            ?? parsed["cover_tone"].flatMap { $0.isTruthy ? $0.stringValue : nil }
        return [
            "subject": .string(String((rawSubject.isEmpty ? "来自张平" : rawSubject).prefix(40))),
            "body": .string(body),
            "sticker": sticker.isEmpty ? .null : .string(sticker),
            "coverTone": .string(normalizedTone(toneValue)),
            "replyToId": replyTo.map(MailboxJSONValue.string) ?? .null
        ]
    }

    /// Merge normalized AI fields into an existing record, matching dictionary update semantics.
    public static func mergeAIParsed(_ parsed: MailboxRecord, into record: inout MailboxRecord, replyTo: String? = nil) {
        record.merge(applyAIParsed(parsed, replyTo: replyTo)) { _, new in new }
    }
}

/// Serialized, reusable mailbox persistence service. Use one store instance per mailbox directory.
/// The actor serializes operations within this process; it does not provide cross-process locking.
public actor MailboxServiceStore {
    public let directoryURL: URL
    private let fileManager: FileManager
    private let clock: @Sendable () -> Int64
    private let identifierGenerator: @Sendable () -> String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        clock: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
        identifierGenerator: @escaping @Sendable () -> String = { "pc_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased() }
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.clock = clock
        self.identifierGenerator = identifierGenerator
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.decoder = JSONDecoder()
    }

    public func cardURL(for cardID: String) throws -> URL {
        guard MailboxService.isSafeID(cardID) else { throw MailboxServiceError.invalidRecord("Invalid postcard ID") }
        return directoryURL.appendingPathComponent(cardID + ".json", isDirectory: false)
    }

    public var indexURL: URL { directoryURL.appendingPathComponent("_index.json", isDirectory: false) }

    public func emptyCard(
        fromRole: String,
        subject: String = "",
        body: String = "",
        sticker: String? = nil,
        coverTone: String = "warm",
        replyTo: String? = nil
    ) -> MailboxRecord {
        let now = clock()
        let trimmedSubject = String(subject.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let trimmedBody = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        return [
            "id": .string(identifierGenerator()),
            "from": .string(fromRole),
            "to": .string(fromRole == "user" ? "ai" : "user"),
            "subject": .string(trimmedSubject),
            "body": .string(trimmedBody),
            "sticker": (sticker?.isEmpty == false) ? .string(sticker!) : .null,
            "coverTone": .string(MailboxService.normalizedTone(coverTone)),
            "replyToId": replyTo.map(MailboxJSONValue.string) ?? .null,
            "read": .bool(fromRole == "user"),
            "createdAt": .integer(now),
            "updatedAt": .integer(now)
        ]
    }

    /// Invalid IDs, absent files, malformed JSON, and records without a truthy id return nil.
    public func readCard(_ cardID: String?) -> MailboxRecord? {
        guard let cardID, MailboxService.isSafeID(cardID) else { return nil }
        let url = directoryURL.appendingPathComponent(cardID + ".json", isDirectory: false)
        guard let data = try? Data(contentsOf: url),
              let value = try? decoder.decode(MailboxJSONValue.self, from: data),
              let record = value.objectValue,
              let id = record["id"], id.isTruthy else { return nil }
        return record
    }

    /// Writes the card first, then updates the summary index. The card ID is replaced if unsafe.
    @discardableResult
    public func writeCard(_ input: MailboxRecord) throws -> MailboxRecord {
        try ensureDirectory()
        var card = input
        let requestedID = card["id"]?.stringValue
        let cardID = MailboxService.isSafeID(requestedID) ? requestedID! : identifierGenerator()
        guard MailboxService.isSafeID(cardID) else {
            throw MailboxServiceError.invalidRecord("Identifier generator returned an unsafe postcard ID")
        }
        card["id"] = .string(cardID)
        card["coverTone"] = .string(MailboxService.normalizedTone(card["coverTone"]?.stringValue))
        card["updatedAt"] = .integer(clock())
        let data: Data
        do {
            data = try encoder.encode(MailboxJSONValue.object(card))
            try data.write(to: directoryURL.appendingPathComponent(cardID + ".json"), options: .atomic)
        } catch {
            throw MailboxServiceError.filesystem(error.localizedDescription)
        }
        try upsertIndex(card)
        return card
    }

    public func cardSummary(_ card: MailboxRecord) -> MailboxRecord {
        let body = (card["body"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectValue = card["subject"].flatMap { $0.isTruthy ? $0 : nil } ?? .string("")
        return [
            "id": card["id"] ?? .null,
            "from": card["from"] ?? .null,
            "to": card["to"] ?? .null,
            "subject": subjectValue,
            "preview": .string(String(body.prefix(48))),
            "sticker": card["sticker"] ?? .null,
            "coverTone": .string(MailboxService.normalizedTone(card["coverTone"]?.stringValue)),
            "replyToId": card["replyToId"] ?? .null,
            "read": .bool(card["read"]?.isTruthy ?? false),
            "createdAt": (card["createdAt"].flatMap { $0.isTruthy ? $0 : nil }) ?? .integer(0)
        ]
    }

    public func loadIndex() -> MailboxRecord {
        guard let data = try? Data(contentsOf: indexURL),
              let value = try? decoder.decode(MailboxJSONValue.self, from: data),
              let object = value.objectValue,
              object["items"]?.arrayValue != nil else {
            return ["items": .array([])]
        }
        return object
    }

    public func saveIndex(_ index: MailboxRecord) throws {
        try ensureDirectory()
        do {
            let data = try encoder.encode(MailboxJSONValue.object(index))
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw MailboxServiceError.filesystem(error.localizedDescription)
        }
    }

    private func upsertIndex(_ card: MailboxRecord) throws {
        var index = loadIndex()
        let current = index["items"]?.arrayValue ?? []
        var items = current.filter { item in
            item.objectValue?["id"] != card["id"]
        }
        items.insert(.object(cardSummary(card)), at: 0)
        items.sort { lhs, rhs in
            let left = lhs.objectValue?["createdAt"].flatMap { $0.integerLike } ?? 0
            let right = rhs.objectValue?["createdAt"].flatMap { $0.integerLike } ?? 0
            return left > right
        }
        index["items"] = .array(Array(items.prefix(200)))
        try saveIndex(index)
    }

    /// Reconstructs the summary index from valid postcard files. Returns the number of cards indexed.
    @discardableResult
    public func rebuildIndex() throws -> Int {
        try ensureDirectory()
        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "_index.json" }
        } catch {
            throw MailboxServiceError.filesystem(error.localizedDescription)
        }
        var cards: [MailboxRecord] = []
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            guard MailboxService.isSafeID(name), let card = readCard(name) else { continue }
            cards.append(card)
        }
        cards.sort {
            let lhs = $0["createdAt"]?.integerLike ?? 0
            let rhs = $1["createdAt"]?.integerLike ?? 0
            return lhs > rhs
        }
        let summaries = cards.prefix(200).map { MailboxJSONValue.object(cardSummary($0)) }
        try saveIndex(["items": .array(Array(summaries))])
        return summaries.count
    }

    public func listCards(folder: MailboxFolder = .all, limit: Int = 60) -> [MailboxRecord] {
        let items = loadIndex()["items"]?.arrayValue ?? []
        let filtered = items.compactMap(\.objectValue).filter { item in
            switch folder {
            case .all: return true
            case .inbox: return item["from"]?.stringValue == "ai"
            case .outbox: return item["from"]?.stringValue == "user"
            case .unread: return item["from"]?.stringValue == "ai" && !(item["read"]?.isTruthy ?? false)
            }
        }
        let end: Int
        if limit >= 0 {
            end = min(filtered.count, limit)
        } else {
            // Avoid overflow for extremely negative values while preserving Python slice behavior.
            end = max(0, filtered.count - min(filtered.count, limit.magnitude > UInt(filtered.count) ? filtered.count : Int(limit.magnitude)))
        }
        return Array(filtered.prefix(end))
    }

    public func unreadCount() -> Int {
        listCards(folder: .unread, limit: 200).count
    }

    @discardableResult
    public func markRead(_ cardID: String) throws -> MailboxRecord? {
        guard var card = readCard(cardID) else { return nil }
        if !(card["read"]?.isTruthy ?? false) {
            card["read"] = .bool(true)
            return try writeCard(card)
        }
        return card
    }

    public func markAllInboxRead() throws -> [String] {
        var changed: [String] = []
        for item in listCards(folder: .unread, limit: 200) {
            guard let id = item["id"]?.stringValue, let card = try markRead(id), let updatedID = card["id"]?.stringValue else { continue }
            changed.append(updatedID)
        }
        return changed
    }

    @discardableResult
    public func createUserCard(subject: String? = nil, body: String, sticker: String? = nil, coverTone: String = "warm") throws -> MailboxRecord {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw MailboxServiceError.invalidRecord("明信片正文不能为空") }
        let chosenSubject = (subject?.isEmpty == false) ? subject! : "给张平"
        let card = emptyCard(fromRole: "user", subject: chosenSubject, body: trimmedBody, sticker: sticker, coverTone: coverTone)
        return try writeCard(card)
    }

    @discardableResult
    public func createAICard(subject: String? = nil, body: String, sticker: String? = nil, coverTone: String = "warm", replyTo: String? = nil) throws -> MailboxRecord {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw MailboxServiceError.invalidRecord("AI 明信片正文为空") }
        let chosenSubject = (subject?.isEmpty == false) ? subject! : "来自张平"
        var card = emptyCard(fromRole: "ai", subject: chosenSubject, body: trimmedBody, sticker: sticker, coverTone: coverTone, replyTo: replyTo)
        card["read"] = .bool(false)
        return try writeCard(card)
    }

    public func applyAIParsed(_ parsed: MailboxRecord, replyTo: String? = nil) -> MailboxRecord {
        MailboxService.applyAIParsed(parsed, replyTo: replyTo)
    }

    public func mergeAIParsed(_ parsed: MailboxRecord, into record: inout MailboxRecord, replyTo: String? = nil) {
        MailboxService.mergeAIParsed(parsed, into: &record, replyTo: replyTo)
    }

    public func buildReplyPrompt(userCard: MailboxRecord, recentDialog: String = "", stickerBlock: String = "") -> String {
        MailboxPrompts.reply(userCard: userCard, recentDialog: recentDialog, stickerBlock: stickerBlock)
    }

    public func buildProactivePrompt(recentDialog: String = "", stickerBlock: String = "") -> String {
        MailboxPrompts.proactive(recentDialog: recentDialog, stickerBlock: stickerBlock)
    }

    public func recentAIContextBlock(limit: Int = 2) -> String {
        let inbox = listCards(folder: .inbox, limit: limit)
        guard !inbox.isEmpty else { return "" }
        var lines = ["\n\n【信箱 — 张平最近寄给她的明信片】"]
        for item in inbox {
            guard let id = item["id"]?.stringValue, let card = readCard(id) else { continue }
            let flag = (card["read"]?.isTruthy ?? false) ? "已读" : "未读"
            let subject = (card["subject"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let body = (card["body"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("- （\(flag)）\(subject)：\(String(body.prefix(120)))")
        }
        lines.append("若她提到明信片/信箱，可自然关联；不要主动复述全文。")
        return lines.joined(separator: "\n")
    }

    private func ensureDirectory() throws {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw MailboxServiceError.filesystem(error.localizedDescription)
        }
    }
}
