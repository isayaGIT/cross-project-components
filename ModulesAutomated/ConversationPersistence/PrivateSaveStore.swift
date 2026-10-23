import Foundation
import SQLite3
import CoreFoundation

public struct PrivateMessage: Codable, Sendable {
    public var id: String
    public var role: String
    public var content: String
    public var image: String?
    public var imageInfo: String?
    public var variants: JSONValue?
    public var variantIndex: Int
    public var kind: String
    public var stickerId: String?
    public var audioUuid: String?
    public var audioUuids: JSONValue?
    public var replyTo: JSONValue?
    public var recalled: Bool
    public var createdAt: Int64

    enum CodingKeys: String, CodingKey { case id, role, content, image, imageInfo, variants, variantIndex, kind, stickerId, audioUuid, audioUuids, replyTo, recalled, createdAt }
}

public final class PrivateSaveStore: SaveStore, @unchecked Sendable {
    public let channel: SaveChannel = .private
    private let configuration: SavePersistenceConfiguration
    private let writeGate: SaveWriteGate
    private let lock = NSRecursiveLock()
    private let fileManager = FileManager.default

    public init(configuration: SavePersistenceConfiguration, writeGate: SaveWriteGate = SaveWriteGate()) {
        self.configuration = configuration; self.writeGate = writeGate
    }

    public var privateDirectory: URL { configuration.rootDirectory.appendingPathComponent("private_chat", isDirectory: true) }
    public var databaseURL: URL { privateDirectory.appendingPathComponent("private_chat.db") }
    public var imagesDirectory: URL { privateDirectory.appendingPathComponent("images", isDirectory: true) }
    public var audioDirectory: URL { privateDirectory.appendingPathComponent("audio", isDirectory: true) }
    public var recalledDirectory: URL { privateDirectory.appendingPathComponent("recalled", isDirectory: true) }
    public var personaDirectory: URL { privateDirectory.appendingPathComponent("persona", isDirectory: true) }

    private func ensureDirectories() throws {
        for url in [privateDirectory, imagesDirectory, audioDirectory, recalledDirectory, personaDirectory] {
            do { try fileManager.createDirectory(at: url, withIntermediateDirectories: true) }
            catch { throw SaveStoreError.filesystem(error.localizedDescription) }
        }
    }

    private func openDatabase() throws -> OpaquePointer {
        try ensureDirectories()
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open database"
            if let db { sqlite3_close(db) }
            throw SaveStoreError.sqlite(message)
        }
        sqlite3_busy_timeout(db, 5000)
        return db
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(db)); sqlite3_free(error)
            throw SaveStoreError.sqlite(message)
        }
    }

    private func columns(_ db: OpaquePointer) throws -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(private_messages)", -1, &statement, nil) == SQLITE_OK else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
        defer { sqlite3_finalize(statement) }
        var result = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW { if let name = sqlite3_column_text(statement, 1) { result.insert(String(cString: name)) } }
        return result
    }

    public func ensureDatabase(migrateLegacyAudioFrom audioRoot: URL? = nil) throws {
        try lock.withLock {
            let legacyDB = configuration.rootDirectory.appendingPathComponent("private_chat.db")
            if fileManager.fileExists(atPath: legacyDB.path) && !fileManager.fileExists(atPath: databaseURL.path) {
                try ensureDirectories()
                do { try fileManager.moveItem(at: legacyDB, to: databaseURL) } catch { throw SaveStoreError.filesystem("legacy database migration failed: \(error.localizedDescription)") }
            }
            let legacyPersona = configuration.rootDirectory.appendingPathComponent("private_persona", isDirectory: true)
            if fileManager.fileExists(atPath: legacyPersona.path) {
                try ensureDirectories()
                if let items = try? fileManager.contentsOfDirectory(at: legacyPersona, includingPropertiesForKeys: nil) {
                    for item in items {
                        let destination = personaDirectory.appendingPathComponent(item.lastPathComponent)
                        if !fileManager.fileExists(atPath: destination.path) { try? fileManager.moveItem(at: item, to: destination) }
                    }
                    if (try? fileManager.contentsOfDirectory(atPath: legacyPersona.path).isEmpty) == true { try? fileManager.removeItem(at: legacyPersona) }
                }
            }
            let db = try openDatabase(); defer { sqlite3_close(db) }
            try execute(db, "CREATE TABLE IF NOT EXISTS private_messages (id TEXT PRIMARY KEY, role TEXT NOT NULL, content TEXT NOT NULL, image TEXT, created_at INTEGER NOT NULL)")
            try execute(db, "CREATE INDEX IF NOT EXISTS idx_private_created_at ON private_messages(created_at)")
            let existing = try columns(db)
            let migrations: [(String, String)] = [
                ("audio_uuid", "ALTER TABLE private_messages ADD COLUMN audio_uuid TEXT"),
                ("audio_uuids", "ALTER TABLE private_messages ADD COLUMN audio_uuids TEXT"),
                ("image_info", "ALTER TABLE private_messages ADD COLUMN image_info TEXT"),
                ("variants", "ALTER TABLE private_messages ADD COLUMN variants TEXT"),
                ("variant_index", "ALTER TABLE private_messages ADD COLUMN variant_index INTEGER DEFAULT 0"),
                ("kind", "ALTER TABLE private_messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'"),
                ("recalled", "ALTER TABLE private_messages ADD COLUMN recalled INTEGER NOT NULL DEFAULT 0"),
                ("reply_to", "ALTER TABLE private_messages ADD COLUMN reply_to TEXT"),
                ("sticker_id", "ALTER TABLE private_messages ADD COLUMN sticker_id TEXT"),
                ("client_id", "ALTER TABLE private_messages ADD COLUMN client_id TEXT")
            ]
            for (name, sql) in migrations where !existing.contains(name) { try execute(db, sql) }
            try execute(db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_private_client_id ON private_messages(client_id) WHERE client_id IS NOT NULL AND client_id != ''")
            try execute(db, "PRAGMA user_version = 1")
            if let audioRoot { try migrateAudioReferences(db: db, from: audioRoot) }
        }
    }

    private func migrateAudioReferences(db: OpaquePointer, from sourceRoot: URL) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT audio_uuid, audio_uuids FROM private_messages", -1, &statement, nil) == SQLITE_OK else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
        defer { sqlite3_finalize(statement) }
        var uuids = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, 0) { uuids.insert(String(cString: raw)) }
            if let raw = sqlite3_column_text(statement, 1), let data = String(cString: raw).data(using: .utf8), let list = try? JSONSerialization.jsonObject(with: data) as? [String] { uuids.formUnion(list.filter { !$0.isEmpty }) }
        }
        for id in uuids where !id.isEmpty {
            let source = sourceRoot.appendingPathComponent(id + ".mp3"); let destination = audioDirectory.appendingPathComponent(id + ".mp3")
            if fileManager.fileExists(atPath: source.path) && !fileManager.fileExists(atPath: destination.path) { try? fileManager.moveItem(at: source, to: destination) }
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) {
        if let value { sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(statement, index) }
    }
    private func bind(_ value: Int64, to index: Int32, in statement: OpaquePointer) { sqlite3_bind_int64(statement, index, value) }
    private func json(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func jsonFromColumn(_ statement: OpaquePointer, _ index: Int32) -> JSONValue? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL, let raw = sqlite3_column_text(statement, index), let data = String(cString: raw).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }
    private func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL, let raw = sqlite3_column_text(statement, index) else { return nil }; return String(cString: raw)
    }
    private func run(_ sql: String, bindings: ((OpaquePointer) -> Void)? = nil) throws -> Int {
        try ensureDatabase()
        return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            defer { sqlite3_finalize(statement) }; bindings?(statement)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            return Int(sqlite3_changes(db))
        }
    }

    public func insertMessage(_ data: [String: JSONValue], createdAt: Int64? = nil, stickerCatalog: [[String: JSONValue]]? = nil, normalizeSticker: (@Sendable (String?, [[String: JSONValue]]) -> String?)? = nil) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let roleRaw = data["role"]?.stringValue ?? "user"; let role = ["user", "assistant"].contains(roleRaw) ? roleRaw : "user"
        let content = data["content"]?.stringValue ?? ""; let image = data["image"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let imageInfo = data["imageInfo"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let kindRaw = data["kind"]?.stringValue ?? "text"; let stickerRaw = data["stickerId"]?.stringValue ?? data["sticker_id"]?.stringValue
        var kind = kindRaw; var stickerID: String?
        if kind == "sticker" || stickerRaw != nil {
            guard let stickerCatalog, let normalizeSticker else { return .error("贴纸校验未配置") }
            guard let normalized = normalizeSticker(stickerRaw, stickerCatalog), !normalized.isEmpty else { return .error("无效的表情包") }
            stickerID = normalized; kind = "sticker"
        }
        if content.isEmpty && image == nil && kind != "voice" && kind != "sticker" { return .error("消息为空") }
        let clientID = String((data["clientId"]?.stringValue ?? data["client_id"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        let id = "pm_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12)
        let timestamp = createdAt ?? data["createdAt"]?.intValue ?? Int64(Date().timeIntervalSince1970 * 1000)
        try ensureDatabase()
        return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }
            if !clientID.isEmpty {
                var check: OpaquePointer?
                guard sqlite3_prepare_v2(db, "SELECT id, created_at FROM private_messages WHERE client_id = ?", -1, &check, nil) == SQLITE_OK, let check else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
                defer { sqlite3_finalize(check) }; bind(clientID, to: 1, in: check)
                if sqlite3_step(check) == SQLITE_ROW {
                    var result = SaveOperationResult(); result.messageID = text(check, 0); result.createdAt = sqlite3_column_int64(check, 1); result.deduped = true; result.role = role; result.kind = kind; return result
                }
            }
            let sql = "INSERT INTO private_messages (id, role, content, image, image_info, variants, variant_index, kind, sticker_id, audio_uuid, audio_uuids, reply_to, created_at, client_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            defer { sqlite3_finalize(statement) }
            bind(String(id), to: 1, in: statement); bind(role, to: 2, in: statement); bind(content, to: 3, in: statement); bind(image, to: 4, in: statement); bind(imageInfo, to: 5, in: statement); bind(json(data["variants"]), to: 6, in: statement); sqlite3_bind_int(statement, 7, Int32(data["variantIndex"]?.intValue ?? 0)); bind(kind, to: 8, in: statement); bind(stickerID, to: 9, in: statement); bind(data["audioUuid"]?.stringValue, to: 10, in: statement); bind(json(data["audioUuids"]), to: 11, in: statement); bind(json(data["replyTo"]), to: 12, in: statement); bind(timestamp, to: 13, in: statement); bind(clientID.isEmpty ? nil : clientID, to: 14, in: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            var result = SaveOperationResult(); result.messageID = String(id); result.createdAt = timestamp; result.role = role; result.kind = kind; result.deduped = false; return result
        }
    }

    public func loadWindow(limit rawLimit: Int = 50, before: Int64 = 0) throws -> SaveWindow {
        let limit = max(1, min(rawLimit == 0 ? 50 : rawLimit, 200)); try ensureDatabase()
        return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }
            let sql = before != 0 ? "SELECT id, role, content, image, image_info, variants, variant_index, kind, sticker_id, audio_uuid, audio_uuids, reply_to, recalled, created_at FROM private_messages WHERE created_at < ? ORDER BY created_at DESC, id DESC LIMIT ?" : "SELECT id, role, content, image, image_info, variants, variant_index, kind, sticker_id, audio_uuid, audio_uuids, reply_to, recalled, created_at FROM private_messages ORDER BY created_at DESC, id DESC LIMIT ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            defer { sqlite3_finalize(statement) }
            var index: Int32 = 1; if before != 0 { bind(before, to: index, in: statement); index += 1 }; sqlite3_bind_int(statement, index, Int32(limit + 1))
            var rows: [[String: JSONValue]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [String: JSONValue] = ["id": .string(text(statement, 0) ?? ""), "role": .string(text(statement, 1) ?? "user"), "content": .string(text(statement, 2) ?? ""), "variantIndex": .integer(Int64(sqlite3_column_int(statement, 6))), "kind": .string(text(statement, 7) ?? "text"), "recalled": .bool(sqlite3_column_int(statement, 12) != 0), "createdAt": .integer(sqlite3_column_int64(statement, 13))]
                for (key, column) in [("image", 3), ("imageInfo", 4), ("stickerId", 8), ("audioUuid", 9)] { if let value = text(statement, Int32(column)) { row[key] = .string(value) } else { row[key] = .null } }
                for (key, column) in [("variants", 5), ("audioUuids", 10), ("replyTo", 11)] { row[key] = jsonFromColumn(statement, Int32(column)) ?? .null }
                rows.append(row)
            }
            let hasMore = rows.count > limit; if hasMore { rows.removeLast() }; rows.reverse()
            return SaveWindow(messages: rows, hasMore: hasMore)
        }
    }

    public func deleteMessage(_ rawID: String) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines); guard !id.isEmpty else { return .error("缺少 messageId") }
        let count = try run("DELETE FROM private_messages WHERE id = ?") { bind(id, to: 1, in: $0) }
        var result = SaveOperationResult(); result.deleted = count; return result
    }

    public func recallMessage(_ rawID: String) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines); guard !id.isEmpty else { return .error("缺少 messageId") }
        try ensureDatabase(); return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }
            var query: OpaquePointer?; guard sqlite3_prepare_v2(db, "SELECT image FROM private_messages WHERE id = ?", -1, &query, nil) == SQLITE_OK, let query else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; defer { sqlite3_finalize(query) }; bind(id, to: 1, in: query)
            let image = sqlite3_step(query) == SQLITE_ROW ? (text(query, 0) ?? "") : ""
            var update: OpaquePointer?; guard sqlite3_prepare_v2(db, "UPDATE private_messages SET recalled = 1, image = NULL WHERE id = ?", -1, &update, nil) == SQLITE_OK, let update else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; defer { sqlite3_finalize(update) }; bind(id, to: 1, in: update); guard sqlite3_step(update) == SQLITE_DONE else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            var result = SaveOperationResult(); result.recalled = true; result.imageName = image; return result
        }
    }

    public func updateMessage(_ data: [String: JSONValue]) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let id = data["messageId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; guard !id.isEmpty else { return .error("缺少 messageId") }
        let mappings: [(String, String, Bool)] = [("content", "content", false), ("imageInfo", "image_info", false), ("variants", "variants", true), ("variantIndex", "variant_index", false), ("audioUuid", "audio_uuid", false), ("audioUuids", "audio_uuids", true), ("kind", "kind", false), ("stickerId", "sticker_id", false)]
        var assignments: [String] = []; var values: [JSONValue?] = []
        for (key, column, isJSON) in mappings where data[key] != nil { assignments.append("\(column) = ?"); values.append(isJSON ? .string(json(data[key]) ?? "null") : data[key]) }
        if data["sticker_id"] != nil && data["stickerId"] == nil { assignments.append("sticker_id = ?"); values.append(data["sticker_id"]) }
        guard !assignments.isEmpty else { return .error("无可更新字段") }
        try ensureDatabase(); return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }
            func perform(whereClause: String, finalID: String) throws -> Int {
                var statement: OpaquePointer?; let sql = "UPDATE private_messages SET \(assignments.joined(separator: ", ")) WHERE \(whereClause)"
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; defer { sqlite3_finalize(statement) }
                for (offset, value) in values.enumerated() { let i = Int32(offset + 1); switch value { case .string(let v): bind(v, to: i, in: statement); case .integer(let v): bind(v, to: i, in: statement); case .bool(let v): sqlite3_bind_int(statement, i, v ? 1 : 0); case .null, .none: sqlite3_bind_null(statement, i); default: bind(json(value), to: i, in: statement) } }
                bind(finalID, to: Int32(values.count + 1), in: statement); guard sqlite3_step(statement) == SQLITE_DONE else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; return Int(sqlite3_changes(db))
            }
            var count = try perform(whereClause: "id = ?", finalID: id); var actualID = id
            if count == 0, let client = data["clientId"]?.stringValue ?? data["client_id"]?.stringValue, !client.isEmpty { count = try perform(whereClause: "client_id = ?", finalID: client); if count > 0 { actualID = client } }
            var result = SaveOperationResult(); result.updated = count; result.messageID = actualID; return result
        }
    }

    public func getMessageImage(_ rawID: String) throws -> String {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines); guard !id.isEmpty else { return "" }; try ensureDatabase()
        return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }; var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT image FROM private_messages WHERE id = ?", -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; defer { sqlite3_finalize(statement) }; bind(id, to: 1, in: statement)
            return sqlite3_step(statement) == SQLITE_ROW ? (text(statement, 0) ?? "") : ""
        }
    }

    public func fetchDialogRows(startMS: Int64, endMS: Int64, limit: Int = 40) throws -> [[String: JSONValue]] {
        try queryRows("SELECT role, content, image_info, kind, sticker_id, created_at FROM private_messages WHERE recalled=0 AND created_at >= ? AND created_at <= ? ORDER BY created_at ASC LIMIT ?", bindings: { statement in bind(startMS, to: 1, in: statement); bind(endMS, to: 2, in: statement); sqlite3_bind_int(statement, 3, Int32(limit)) })
    }

    public func fetchRecentRoleContent(limit: Int = 24) throws -> [[String: JSONValue]] {
        let rows = try queryRows("SELECT role, content FROM private_messages ORDER BY created_at DESC, id DESC LIMIT ?", bindings: { sqlite3_bind_int($0, 1, Int32(limit)) })
        return rows.reversed().map { ["role": $0["role"] ?? .string(""), "content": $0["content"] ?? .string("")] }
    }

    public func fetchUserSince(sessionStartMS: Int64) throws -> [[String: JSONValue]] {
        try queryRows("SELECT content, image_info, kind, sticker_id, created_at FROM private_messages WHERE role='user' AND recalled=0 AND created_at >= ? ORDER BY created_at ASC", bindings: { bind(sessionStartMS, to: 1, in: $0) })
    }

    private func queryRows(_ sql: String, bindings: (OpaquePointer) -> Void) throws -> [[String: JSONValue]] {
        try ensureDatabase(); return try lock.withLock {
            let db = try openDatabase(); defer { sqlite3_close(db) }; var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw SaveStoreError.sqlite(String(cString: sqlite3_errmsg(db))) }; defer { sqlite3_finalize(statement) }; bindings(statement)
            var result: [[String: JSONValue]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [String: JSONValue] = [:]; let count = Int(sqlite3_column_count(statement))
                for index in 0..<count {
                    let key = String(cString: sqlite3_column_name(statement, Int32(index)))
                    switch sqlite3_column_type(statement, Int32(index)) {
                    case SQLITE_INTEGER: row[key] = .integer(sqlite3_column_int64(statement, Int32(index)))
                    case SQLITE_FLOAT: row[key] = .number(sqlite3_column_double(statement, Int32(index)))
                    case SQLITE_TEXT: row[key] = .string(String(cString: sqlite3_column_text(statement, Int32(index))))
                    case SQLITE_NULL: row[key] = .null
                    default: row[key] = .null
                    }
                }; result.append(row)
            }; return result
        }
    }

    public func upsert(message: [String: JSONValue]?, messages: [[String: JSONValue]]?, meta: [String: JSONValue]?, context: [String: JSONValue]) async throws -> SaveOperationResult {
        let message = message ?? messages?.first
        guard let message else { return .error("缺少 message") }
        return try insertMessage(message, createdAt: context["created_at"]?.intValue)
    }

    public func loadWindow(limit: Int, before: JSONValue?, context: [String: JSONValue]) async throws -> [String: JSONValue] {
        let beforeValue = before?.intValue ?? 0; let window = try loadWindow(limit: limit, before: beforeValue)
        return ["messages": .array(window.messages.map(JSONValue.object)), "hasMore": .bool(window.hasMore)]
    }

    public func patchMeta(_ meta: [String: JSONValue], context: [String: JSONValue]) async throws -> SaveOperationResult {
        var result = SaveOperationResult(); result.message = "private has no meta file"; return result
    }
}
