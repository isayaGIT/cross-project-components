import Foundation

public final class StorySaveStore: SaveStore, @unchecked Sendable {
    public let channel: SaveChannel = .story
    private let configuration: SavePersistenceConfiguration
    private let writeGate: SaveWriteGate
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(configuration: SavePersistenceConfiguration, writeGate: SaveWriteGate = SaveWriteGate()) {
        self.configuration = configuration
        self.writeGate = writeGate
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; self.encoder = encoder
    }

    private func root() throws -> URL {
        let url = configuration.rootDirectory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.resolvingSymlinksInPath().standardizedFileURL
    }

    public func fileURL(chatID: String) throws -> URL {
        let id = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.count <= 128, !id.contains(".."), !id.contains("/"), !id.contains("\\") else { throw SaveStoreError.invalidChatID }
        let rootURL = try root()
        let candidate = rootURL.appendingPathComponent(id + ".json").standardizedFileURL
        guard candidate.deletingLastPathComponent() == rootURL else { throw SaveStoreError.invalidChatID }
        return candidate
    }

    private func read(_ url: URL) throws -> [String: JSONValue]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        if let object = try? JSONSerialization.jsonObject(with: data), let dict = object as? [String: Any] {
            return dict.mapValues(JSONValue.from)
        }
        // Python's raw_decode accepts a valid first JSON value followed by trailing bytes.
        if let text = String(data: data, encoding: .utf8) {
            var end = text.endIndex
            while end > text.startIndex {
                let candidate = String(text[..<end])
                if let bytes = candidate.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: bytes), let dict = object as? [String: Any] { return dict.mapValues(JSONValue.from) }
                end = text.index(before: end)
            }
        }
        return nil
    }

    private func writeAtomically(_ document: [String: JSONValue], to url: URL) throws {
        let object = document.mapValues(\.foundationValue)
        guard JSONSerialization.isValidJSONObject(object) else { throw SaveStoreError.invalidPayload("invalid payload") }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        try lock.withLock {
            let temporary = url.appendingPathExtension("tmp")
            do { try data.write(to: temporary, options: .atomic); if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }; try FileManager.default.moveItem(at: temporary, to: url) }
            catch { try? FileManager.default.removeItem(at: temporary); throw SaveStoreError.filesystem(error.localizedDescription) }
        }
    }

    private func string(_ value: JSONValue?) -> String? { value?.stringValue }
    private func dictionary(_ value: JSONValue?) -> [String: JSONValue]? { value?.objectValue }
    private func array(_ value: JSONValue?) -> [JSONValue]? { value?.arrayValue }

    public func loadDocument(chatID: String) throws -> [String: JSONValue] {
        let url = try fileURL(chatID: chatID)
        guard var document = try read(url) else { return ["messages": .object([:]), "modules": .array([]), "id": .string(chatID), "rootId": .null] }
        if document["id"] == nil { document["id"] = .string(chatID) }
        return document
    }

    public func activePathIDs(messages: [String: JSONValue], rootID: String?, activeBranches: [String: JSONValue]) -> [String] {
        var result: [String] = []; var seen = Set<String>(); var next = rootID
        while let id = next, !seen.contains(id) {
            seen.insert(id)
            guard let node = messages[id]?.objectValue else { break }
            result.append(id)
            if let active = activeBranches[id]?.stringValue, !active.isEmpty { next = active }
            else { next = node["childrenIds"]?.arrayValue?.first?.stringValue }
        }
        return result
    }

    private func collectWindow(messages: [String: JSONValue], path: [String], limit: Int, before: String?) -> (ids: [String], hasMore: Bool, subset: [String: JSONValue]) {
        var selectedPath = path
        if let before, let index = selectedPath.firstIndex(of: before) { selectedPath = Array(selectedPath[..<index]) }
        let hasMore = selectedPath.count > limit
        let ids = limit > 0 ? Array(selectedPath.suffix(limit)) : selectedPath
        var needed = Set(ids)
        for id in ids {
            guard let node = messages[id]?.objectValue else { continue }
            if let parentID = node["parentId"]?.stringValue, let parent = messages[parentID]?.objectValue {
                needed.insert(parentID)
                for child in parent["childrenIds"]?.arrayValue?.compactMap(\.stringValue) ?? [] where messages[child] != nil { needed.insert(child) }
            }
        }
        return (ids, hasMore, messages.filter { needed.contains($0.key) })
    }

    public func loadWindow(chatID: String, limit rawLimit: Int = 50, before: String? = nil, full: Bool = false) throws -> [String: JSONValue] {
        let document = try loadDocument(chatID: chatID)
        let messages = document["messages"]?.objectValue ?? [:]
        if full || document["messages"]?.arrayValue != nil {
            var output = document
            let path = document["messages"]?.arrayValue == nil ? activePathIDs(messages: messages, rootID: document["rootId"]?.stringValue, activeBranches: document["activeBranches"]?.objectValue ?? [:]) : []
            output["hasMore"] = .bool(false); output["pathIds"] = .array(path.map(JSONValue.string)); output["window"] = .bool(false)
            return output
        }
        let limit = max(1, min(rawLimit == 0 ? 50 : rawLimit, 200))
        let path = activePathIDs(messages: messages, rootID: document["rootId"]?.stringValue, activeBranches: document["activeBranches"]?.objectValue ?? [:])
        let window = collectWindow(messages: messages, path: path, limit: limit, before: before)
        var subset = window.subset
        for id in document["rootVariants"]?.arrayValue?.compactMap(\.stringValue) ?? [] { if let node = messages[id] { subset[id] = node } }
        return [
            "id": document["id"] ?? .string(chatID), "title": document["title"] ?? .null,
            "titleEdited": document["titleEdited"] ?? .null, "subtitle": document["subtitle"] ?? .null,
            "rootId": document["rootId"] ?? .null, "activeBranches": document["activeBranches"] ?? .object([:]),
            "rootVariants": document["rootVariants"] ?? .array([]), "traceCount": document["traceCount"] ?? .integer(0),
            "modules": document["modules"] ?? .null, "timestamp": document["timestamp"] ?? .null,
            "messages": .object(subset), "pathIds": .array(window.ids.map(JSONValue.string)), "hasMore": .bool(window.hasMore),
            "window": .bool(true), "totalMessages": .integer(Int64(messages.count)), "pathLength": .integer(Int64(path.count))
        ]
    }

    public func saveDocument(_ document: [String: JSONValue]) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let chatID = document["id"]?.stringValue ?? "default"
        let url = try fileURL(chatID: chatID); try writeAtomically(document, to: url)
        var result = SaveOperationResult(); result.path = url.path; result.mode = "full"; result.messageCount = document["messages"]?.objectValue?.count ?? document["messages"]?.arrayValue?.count ?? 0
        return result
    }

    public func patchDocument(_ patch: [String: JSONValue]) throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        let chatID = patch["id"]?.stringValue ?? "default"; let url = try fileURL(chatID: chatID)
        return try lock.withLock {
            var existing = try read(url) ?? ["id": .string(chatID), "messages": .object([:]), "rootId": .null, "activeBranches": .object([:]), "rootVariants": .array([]), "modules": .array([])]
            guard var messages = existing["messages"]?.objectValue else { throw SaveStoreError.legacyFlatDocumentRequiresFullSave }
            var changed = 0
            if let incoming = patch["messages"]?.objectValue { for (id, node) in incoming where !id.isEmpty && node.objectValue != nil { messages[id] = node; changed += 1 } }
            let deleted = patch["deleted"]?.arrayValue ?? []
            for value in deleted { if let id = value.stringValue, messages.removeValue(forKey: id) != nil { changed += 1 } }
            existing["messages"] = .object(messages)
            for key in ["rootId", "activeBranches", "rootVariants", "title", "titleEdited", "subtitle", "traceCount", "modules", "timestamp"] { if let value = patch[key], value != .null { existing[key] = value } }
            existing["id"] = .string(chatID); try writeAtomically(existing, to: url)
            var result = SaveOperationResult(); result.path = url.path; result.mode = "patch"; result.patched = changed; result.messageCount = messages.count; result.deleted = deleted.count
            return result
        }
    }

    public func upsert(message: [String: JSONValue]?, messages: [[String: JSONValue]]?, meta: [String: JSONValue]?, context: [String: JSONValue]) async throws -> SaveOperationResult {
        let data = context["document"]?.objectValue ?? context["data"]?.objectValue ?? meta
        var body = data
        if body == nil, let message, let id = message["id"]?.stringValue {
            let chatID = context["chat_id"]?.stringValue ?? "default"
            body = ["id": .string(chatID), "messages": .object([id: .object(message)]), "mode": .string("patch")]
        }
        guard let body else { return .error("缺少 document") }
        if (body["mode"]?.stringValue ?? context["mode"]?.stringValue ?? "full").lowercased() == "patch" { return try patchDocument(body) }
        return try saveDocument(body)
    }

    public func loadWindow(limit: Int, before: JSONValue?, context: [String: JSONValue]) async throws -> [String: JSONValue] {
        let id = context["chat_id"]?.stringValue ?? context["id"]?.stringValue ?? ""
        let beforeID = context["before_id"]?.stringValue ?? before?.stringValue
        return try loadWindow(chatID: id, limit: limit, before: beforeID, full: context["full"] == .bool(true))
    }

    public func patchMeta(_ meta: [String: JSONValue], context: [String: JSONValue]) async throws -> SaveOperationResult {
        if writeGate.isDisabled() { return writeGate.disabledResponse(channel: channel.rawValue) }
        guard let id = context["chat_id"]?.stringValue ?? meta["id"]?.stringValue else { return .error("缺少 chat_id") }
        var patch = meta; patch["id"] = .string(id); patch["mode"] = .string("patch"); if patch["messages"] == nil { patch["messages"] = .object([:]) }
        return try patchDocument(patch)
    }
}
