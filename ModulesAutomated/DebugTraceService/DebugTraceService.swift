import Foundation

/// Persistent debug-trace store. Operations on one instance are serialized by actor isolation.
/// Separate instances or external processes writing the same URL are not coordinated.
public actor DebugTraceService {
    public static let recentMaximum = 5

    private let fileURL: URL
    private let clock: @Sendable () -> Date
    private let makeIdentifier: @Sendable () -> String
    private let beijingTimeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL,
        clock: @escaping @Sendable () -> Date = { Date() },
        makeIdentifier: @escaping @Sendable () -> String = { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased() }
    ) {
        self.fileURL = fileURL
        self.clock = clock
        self.makeIdentifier = makeIdentifier
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func listAll() -> DebugTraceCollection {
        let storage = loadStorage()
        return DebugTraceCollection(
            recent: storage.recent,
            pinned: storage.pinned,
            recentMax: Self.recentMaximum
        )
    }

    /// Appends a new trace or updates an existing trace without losing omitted optional fields.
    @discardableResult
    public func append(_ raw: [String: TraceJSONValue]) throws -> TraceJSONValue {
        let storage = loadStorage()
        var entry = sanitize(raw)
        let id = entry["id"]?.stringValue ?? makeIdentifier()
        entry["id"] = .string(id)

        if let index = storage.pinned.firstIndex(where: { $0.objectValue?["id"]?.stringValue == id }) {
            entry = mergingPreservedOptionalFields(incoming: entry, existing: storage.pinned[index])
            storage.pinned[index] = .object(entry)
            try saveStorage(storage)
            return .object(entry)
        }
        if let index = storage.recent.firstIndex(where: { $0.objectValue?["id"]?.stringValue == id }) {
            entry = mergingPreservedOptionalFields(incoming: entry, existing: storage.recent[index])
            storage.recent[index] = .object(entry)
            try saveStorage(storage)
            return .object(entry)
        }

        storage.recent.insert(.object(entry), at: 0)
        if storage.recent.count > Self.recentMaximum {
            storage.recent = Array(storage.recent.prefix(Self.recentMaximum))
        }
        try saveStorage(storage)
        return .object(entry)
    }

    /// Pins a recent trace, or creates/updates one from the supplied raw trace.
    @discardableResult
    public func pin(id traceID: String, raw: [String: TraceJSONValue]? = nil) throws -> TraceJSONValue? {
        let normalizedID = traceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty || !(raw ?? [:]).isEmpty else { return nil }
        let storage = loadStorage()
        let recentIndex = normalizedID.isEmpty ? nil : storage.recent.firstIndex { $0.objectValue?["id"]?.stringValue == normalizedID }
        let pinnedIndex = normalizedID.isEmpty ? nil : storage.pinned.firstIndex { $0.objectValue?["id"]?.stringValue == normalizedID }

        var entry: [String: TraceJSONValue]
        if let raw {
            var supplied = raw
            if !normalizedID.isEmpty { supplied["id"] = .string(normalizedID) }
            entry = sanitize(supplied)
            if entry["id"]?.stringValue?.isEmpty != false {
                entry["id"] = .string(makeIdentifier())
            }
            if let recentIndex {
                entry = mergingPreservedOptionalFields(incoming: entry, existing: storage.recent[recentIndex])
            } else if let pinnedIndex {
                entry = mergingPreservedOptionalFields(incoming: entry, existing: storage.pinned[pinnedIndex])
            }
        } else if let recentIndex, let found = storage.recent[recentIndex].objectValue {
            entry = found
            entry["id"] = .string(normalizedID)
        } else if let pinnedIndex, let found = storage.pinned[pinnedIndex].objectValue {
            return .object(found)
        } else {
            return nil
        }

        let finalID = entry["id"]?.stringValue ?? makeIdentifier()
        entry["id"] = .string(finalID)
        storage.recent.removeAll { $0.objectValue?["id"]?.stringValue == finalID }
        storage.pinned.removeAll { $0.objectValue?["id"]?.stringValue == finalID }
        storage.pinned.insert(.object(entry), at: 0)
        try saveStorage(storage)
        return .object(entry)
    }

    @discardableResult
    public func delete(id traceID: String) throws -> Bool {
        let normalizedID = traceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return false }
        let storage = loadStorage()
        let oldRecentCount = storage.recent.count
        let oldPinnedCount = storage.pinned.count
        storage.recent.removeAll { $0.objectValue?["id"]?.stringValue == normalizedID }
        storage.pinned.removeAll { $0.objectValue?["id"]?.stringValue == normalizedID }
        guard storage.recent.count != oldRecentCount || storage.pinned.count != oldPinnedCount else { return false }
        try saveStorage(storage)
        return true
    }

    /// Patches only supported keys. Unsupported fields are ignored, matching the source behavior.
    @discardableResult
    public func patch(id traceID: String, fields: [String: TraceJSONValue]) throws -> TraceJSONValue? {
        let allowed: Set<String> = ["rawOutput", "userInput", "systemPrompt", "recalls", "usage", "usageSource"]
        let patch = fields.filter { allowed.contains($0.key) }
        guard !patch.isEmpty else { throw DebugTraceError.invalidPatch }
        let normalizedID = traceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return nil }

        let storage = loadStorage()
        if let index = storage.recent.firstIndex(where: { $0.objectValue?["id"]?.stringValue == normalizedID }),
           var entry = storage.recent[index].objectValue {
            applyPatch(patch, to: &entry)
            entry = sanitize(entry)
            storage.recent[index] = .object(entry)
            try saveStorage(storage)
            return .object(entry)
        }
        if let index = storage.pinned.firstIndex(where: { $0.objectValue?["id"]?.stringValue == normalizedID }),
           var entry = storage.pinned[index].objectValue {
            applyPatch(patch, to: &entry)
            entry = sanitize(entry)
            storage.pinned[index] = .object(entry)
            try saveStorage(storage)
            return .object(entry)
        }
        return nil
    }

    public func estimateUsageCalibrated(model: String, systemPrompt: String, rawOutput: String) -> DebugTraceUsageEstimate {
        let anthropic = model.lowercased().contains("claude") || model.lowercased().contains("anthropic")
        let rate = anthropic ? 0.85 : 1.6
        let promptCharacters = systemPrompt.unicodeScalars.count
        let outputCharacters = rawOutput.unicodeScalars.count
        let promptTokens = Int(ceil(Double(promptCharacters) / rate))
        let thinkingModel = Self.isThinkingModel(model)
        let completionTokens = thinkingModel
            ? Int(Double(outputCharacters) * 2.46)
            : Int(ceil(Double(outputCharacters) / rate))
        let usage = DebugTraceUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            promptCacheHitTokens: 0,
            promptCacheMissTokens: promptTokens,
            inputTokens: promptTokens,
            outputTokens: completionTokens
        )
        return DebugTraceUsageEstimate(usage: usage, source: "calibrated")
    }

    /// Backfills recent and pinned traces. The counter receives system prompt and raw output.
    /// A nil, throwing, or empty result falls back to the calibrated estimate.
    @discardableResult
    public func backfillUsage(
        model: String,
        counter: (@Sendable (_ prompt: String, _ output: String) throws -> [String: TraceJSONValue]?)? = nil,
        onlyMissing: Bool = true
    ) throws -> Int {
        let storage = loadStorage()
        var updated = 0
        for index in storage.recent.indices {
            if backfillEntry(&storage.recent[index], model: model, counter: counter, onlyMissing: onlyMissing) { updated += 1 }
        }
        for index in storage.pinned.indices {
            if backfillEntry(&storage.pinned[index], model: model, counter: counter, onlyMissing: onlyMissing) { updated += 1 }
        }
        if updated > 0 { try saveStorage(storage) }
        return updated
    }

    // MARK: - Storage

    private struct Storage {
        var recent: [TraceJSONValue] = []
        var pinned: [TraceJSONValue] = []
    }

    private func loadStorage() -> Storage {
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONSerialization.jsonObject(with: data),
              let dictionary = root as? [String: Any] else {
            return Storage()
        }
        let recent: [TraceJSONValue]
        if let values = dictionary["recent"] as? [Any] {
            recent = values.map(TraceJSONValue.init(foundationValue:))
        } else {
            recent = []
        }
        let pinned: [TraceJSONValue]
        if let values = dictionary["pinned"] as? [Any] {
            pinned = values.map(TraceJSONValue.init(foundationValue:))
        } else {
            pinned = []
        }
        return Storage(recent: recent, pinned: pinned)
    }

    private func saveStorage(_ storage: Storage) throws {
        do {
            let root = TraceJSONValue.object([
                "recent": .array(storage.recent),
                "pinned": .array(storage.pinned)
            ])
            let data = try encoder.encode(root)
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw DebugTraceError.persistence(error.localizedDescription)
        }
    }

    // MARK: - Normalization

    private func sanitize(_ raw: [String: TraceJSONValue]) -> [String: TraceJSONValue] {
        let idValue = raw["id"]?.stringValue
        let id = idValue.flatMap { $0.isEmpty ? nil : $0 } ?? makeIdentifier()
        let model = raw["model"]?.stringValue ?? ""
        var result: [String: TraceJSONValue] = [
            "id": .string(id),
            "ts": .string(normalizeTimestamp(raw["ts"]?.stringValue)),
            "slot": .string(raw["slot"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? "chat"),
            "model": .string(model),
            "userInput": .string(raw["userInput"]?.stringValue ?? ""),
            "systemPrompt": .string(raw["systemPrompt"]?.stringValue ?? "")
        ]
        if let rawOutput = raw["rawOutput"]?.stringValue { result["rawOutput"] = .string(rawOutput) }
        if let recalls = raw["recalls"]?.arrayValue {
            result["recalls"] = .array(recalls.prefix(40).compactMap { value in
                guard let item = value.objectValue else { return nil }
                let memory = item["memory"]?.objectValue ?? [:]
                let title = String((memory["title"]?.stringValue ?? "").unicodeScalars.prefix(80).map(String.init).joined())
                let source = String((memory["source"]?.stringValue ?? "").unicodeScalars.prefix(40).map(String.init).joined())
                let content = String((memory["content"]?.stringValue ?? "").unicodeScalars.prefix(200).map(String.init).joined())
                var recall: [String: TraceJSONValue] = [
                    "inject": .bool(item["inject"]?.isTruthy ?? false),
                    "flash": .bool(item["flash"]?.isTruthy ?? false),
                    "memory": .object(["title": .string(title), "source": .string(source), "content": .string(content)])
                ]
                if let score = item["score"] { recall["score"] = score }
                return .object(recall)
            })
        }
        if let usage = normalizeUsage(raw["usage"]) { result["usage"] = usage }
        if let usageSource = raw["usageSource"]?.stringValue, !usageSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result["usageSource"] = .string(usageSource.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }

    private func normalizeUsage(_ value: TraceJSONValue?) -> TraceJSONValue? {
        guard let source = value?.objectValue else { return nil }
        let aliases: [(String, [String])] = [
            ("prompt_tokens", ["prompt_tokens"]),
            ("completion_tokens", ["completion_tokens", "output_tokens"]),
            ("prompt_cache_hit_tokens", ["prompt_cache_hit_tokens"]),
            ("prompt_cache_miss_tokens", ["prompt_cache_miss_tokens"]),
            ("cache_read_input_tokens", ["cache_read_input_tokens"]),
            ("cache_creation_input_tokens", ["cache_creation_input_tokens"]),
            ("input_tokens", ["input_tokens"]),
            ("output_tokens", ["output_tokens", "completion_tokens"])
        ]
        var output: [String: TraceJSONValue] = [:]
        var hasTokens = false
        for (target, keys) in aliases {
            let found = keys.compactMap { source[$0] }.first
            let number = found?.integerValue ?? 0
            output[target] = .integer(number)
            if number != 0 { hasTokens = true }
        }
        let nestedThinking = source["output_tokens_details"]?.objectValue?["thinking_tokens"]?.integerValue
        let thinking = nestedThinking ?? source["thinking_tokens"]?.integerValue ?? source["reasoning_tokens"]?.integerValue ?? 0
        if thinking != 0 {
            output["thinking_tokens"] = .integer(thinking)
            output["output_tokens_details"] = .object(["thinking_tokens": .integer(thinking)])
        }
        if !hasTokens { return nil }
        return .object(output)
    }

    private func normalizeTimestamp(_ input: String?) -> String {
        guard let input else { return formatBeijing(clock()) }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return formatBeijing(clock()) }
        let normalized = value.replacingOccurrences(of: " ", with: "T", range: value.range(of: " "))
        let suffix = normalized.dropFirst(min(10, normalized.count))
        let hasZone = normalized.hasSuffix("Z") || suffix.contains("+") || suffix.dropFirst(max(0, suffix.firstIndex(of: "T").map { suffix.distance(from: suffix.startIndex, to: $0) + 1 } ?? 0)).contains("-")
        if hasZone {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let parsed = formatter.date(from: normalized) ?? {
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: normalized)
            }()
            if let parsed { return formatBeijing(parsed) }
        }
        return String(normalized.prefix(19))
    }

    private func formatBeijing(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = beijingTimeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }

    private func mergingPreservedOptionalFields(
        incoming: [String: TraceJSONValue],
        existing: TraceJSONValue
    ) -> [String: TraceJSONValue] {
        var result = incoming
        guard let old = existing.objectValue else { return result }
        for key in ["rawOutput", "recalls"] where result[key] == nil {
            if let value = old[key] { result[key] = value }
        }
        return result
    }

    private func applyPatch(_ patch: [String: TraceJSONValue], to entry: inout [String: TraceJSONValue]) {
        for (key, value) in patch {
            switch key {
            case "rawOutput", "userInput", "systemPrompt", "usageSource":
                if value.stringValue != nil { entry[key] = value }
            case "recalls":
                if value.arrayValue != nil { entry[key] = value }
            case "usage":
                if value.objectValue != nil { entry[key] = value }
            default:
                break
            }
        }
    }

    private func backfillEntry(
        _ value: inout TraceJSONValue,
        model: String,
        counter: (@Sendable (_ prompt: String, _ output: String) throws -> [String: TraceJSONValue]?)?,
        onlyMissing: Bool
    ) -> Bool {
        guard var entry = value.objectValue else { return false }
        if onlyMissing, entry["usage"]?.isTruthy == true { return false }
        let prompt = entry["systemPrompt"]?.stringValue ?? ""
        let output = entry["rawOutput"]?.stringValue ?? ""
        guard !prompt.isEmpty || !output.isEmpty else { return false }

        var usageValue: TraceJSONValue?
        var source = "count_tokens"
        if let counter, let counted = try? counter(prompt, output), let counted, let normalized = normalizeUsage(.object(counted)) {
            usageValue = normalized
        }
        if usageValue == nil {
            let estimate = estimateUsageCalibrated(model: model.isEmpty ? (entry["model"]?.stringValue ?? "") : model, systemPrompt: prompt, rawOutput: output)
            usageValue = estimate.usage.jsonValue
            source = estimate.source
        }
        guard let usageValue, let usageObject = usageValue.objectValue,
              (usageObject["prompt_tokens"]?.integerValue ?? 0) != 0 || (usageObject["completion_tokens"]?.integerValue ?? 0) != 0 else {
            return false
        }
        entry["usage"] = usageValue
        entry["usageSource"] = .string(source)
        value = .object(sanitize(entry))
        return true
    }

    private static func isThinkingModel(_ model: String) -> Bool {
        let lowered = model.lowercased()
        return ["thinking", "reasoner", "reasoning", "-r1", "o1", "o3", "deepseek-r1"].contains { lowered.contains($0) }
    }
}
