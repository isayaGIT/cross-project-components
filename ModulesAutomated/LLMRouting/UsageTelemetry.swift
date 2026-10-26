import Foundation

/// Actor-isolated persistence and aggregation for LLM usage telemetry.
/// API keys and authorization headers are never persisted or logged.
public actor LLMUsageTelemetry {
    public struct Record: Sendable {
        public let taskKey: String
        public let model: String
        public let apiURL: String
        public let promptTokens: Int
        public let completionTokens: Int
        public let latencyMilliseconds: Int
        public let succeeded: Bool
        public let cacheHitTokens: Int?
        public let cacheMissTokens: Int?

        public init(taskKey: String, model: String, apiURL: String, promptTokens: Int, completionTokens: Int, latencyMilliseconds: Int, succeeded: Bool = true, cacheHitTokens: Int? = nil, cacheMissTokens: Int? = nil) {
            self.taskKey = taskKey; self.model = model; self.apiURL = apiURL
            self.promptTokens = max(0, promptTokens); self.completionTokens = max(0, completionTokens)
            self.latencyMilliseconds = max(0, latencyMilliseconds); self.succeeded = succeeded
            self.cacheHitTokens = cacheHitTokens.map { max(0, $0) }; self.cacheMissTokens = cacheMissTokens.map { max(0, $0) }
        }
    }

    public struct Configuration: Sendable {
        public let usageURL: URL
        public let now: @Sendable () -> Date
        public let beijingClockString: @Sendable () -> String
        public let log: @Sendable (String) -> Void
        public init(usageURL: URL, now: @escaping @Sendable () -> Date = { Date() }, beijingClockString: @escaping @Sendable () -> String = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            return formatter.string(from: Date())
        }, log: @escaping @Sendable (String) -> Void = { print($0) }) {
            self.usageURL = usageURL; self.now = now; self.beijingClockString = beijingClockString; self.log = log
        }
    }

    private let configuration: Configuration
    private let fileManager: FileManager
    private var document: [String: Any]

    public init(configuration: Configuration, fileManager: FileManager = .default) {
        self.configuration = configuration; self.fileManager = fileManager
        self.document = Self.readDocument(at: configuration.usageURL)
    }

    /// Records a call and updates both the task aggregate and local-calendar daily aggregate.
    public func record(_ record: Record) {
        // The Python implementation reloads the JSON file for every record. Refresh here
        // as well so another process or a separate telemetry instance's updates are not
        // silently discarded by a stale actor-local snapshot.
        document = Self.readDocument(at: configuration.usageURL)
        let prompt = record.promptTokens
        let completion = record.completionTokens
        let total = prompt + completion
        let cost = LLMCostAccounting.estimateCost(model: record.model, promptTokens: prompt, completionTokens: completion)
        let host = Self.hostname(from: record.apiURL)
        let time = configuration.beijingClockString()
        let hit = record.cacheHitTokens ?? 0
        let miss = record.cacheMissTokens ?? 0
        let cacheTotal = hit + miss
        let hitPercent = cacheTotal > 0 ? Double(hit) * 100 / Double(cacheTotal) : 0
        configuration.log(String(format: "[LLM %@] %@ | %@ | tokens=%d+%d cost=$%.6f latency=%.3fs ok=%@ cache_hit=%d cache_miss=%d cache_hit_rate=%.1f%%", time, record.taskKey, host, prompt, completion, cost, Double(record.latencyMilliseconds) / 1000, record.succeeded ? "true" : "false", hit, miss, hitPercent))

        var tasks = document["tasks"] as? [String: [String: Any]] ?? [:]
        var task = tasks[record.taskKey] ?? [:]
        Self.increment(&task, key: "calls", by: 1)
        Self.increment(&task, key: record.succeeded ? "successes" : "failures", by: 1)
        Self.increment(&task, key: "prompt_tokens", by: prompt)
        Self.increment(&task, key: "completion_tokens", by: completion)
        Self.increment(&task, key: "total_tokens", by: total)
        Self.increment(&task, key: "latency_ms", by: record.latencyMilliseconds)
        Self.increment(&task, key: "cache_hit_tokens", by: hit)
        Self.increment(&task, key: "cache_miss_tokens", by: miss)
        task["cost_usd"] = Self.number(task["cost_usd"]) + cost
        task["last_model"] = record.model
        task["last_provider"] = host
        task["last_time"] = time
        tasks[record.taskKey] = task
        document["tasks"] = tasks

        var daily = document["daily"] as? [String: [String: Any]] ?? [:]
        let day = Self.dayFormatter.string(from: configuration.now())
        var dayEntry = daily[day] ?? [:]
        Self.increment(&dayEntry, key: "calls", by: 1)
        Self.increment(&dayEntry, key: record.succeeded ? "successes" : "failures", by: 1)
        Self.increment(&dayEntry, key: "prompt_tokens", by: prompt)
        Self.increment(&dayEntry, key: "completion_tokens", by: completion)
        Self.increment(&dayEntry, key: "total_tokens", by: total)
        Self.increment(&dayEntry, key: "latency_ms", by: record.latencyMilliseconds)
        Self.increment(&dayEntry, key: "cache_hit_tokens", by: hit)
        Self.increment(&dayEntry, key: "cache_miss_tokens", by: miss)
        dayEntry["cost_usd"] = Self.number(dayEntry["cost_usd"]) + cost
        daily[day] = dayEntry
        document["daily"] = daily
        persist()
    }

    /// Returns a fresh detached snapshot, including updates made outside this actor.
    public func getUsage() -> [String: Any] {
        document = Self.readDocument(at: configuration.usageURL)
        return document
    }

    public func printRoutingTable(_ routes: [(task: String, provider: String, model: String, hasUISlot: Bool?)]) {
        configuration.log("LLM routing table:")
        for route in routes.sorted(by: { $0.task < $1.task }) {
            configuration.log("- \(route.task): provider=\(route.provider), model=\(route.model), has_ui_slot=\(route.hasUISlot.map(String.init) ?? "unspecified")")
        }
    }

    private func persist() {
        do {
            let parent = configuration.usageURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configuration.usageURL, options: .atomic)
        } catch {
            configuration.log("[LLM telemetry] failed to persist usage data: \(error.localizedDescription)")
        }
    }

    private static func readDocument(at url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data), let dictionary = object as? [String: Any] else {
            return ["tasks": [String: Any](), "daily": [String: Any]()]
        }
        var result = dictionary
        if result["tasks"] as? [String: Any] == nil { result["tasks"] = [String: Any]() }
        if result["daily"] as? [String: Any] == nil { result["daily"] = [String: Any]() }
        return result
    }

    private static func increment(_ dictionary: inout [String: Any], key: String, by amount: Int) {
        dictionary[key] = integer(dictionary[key]) + amount
    }
    private static func integer(_ value: Any?) -> Int {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return 0
    }
    private static func number(_ value: Any?) -> Double {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let number = Double(string) { return number }
        return 0
    }
    private static func hostname(from rawURL: String) -> String {
        guard let components = URLComponents(string: rawURL), let host = components.host, !host.isEmpty else { return "unknown" }
        return host
    }
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"; return formatter
    }()
}
