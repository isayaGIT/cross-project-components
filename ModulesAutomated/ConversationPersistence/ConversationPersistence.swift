import Foundation
import SQLite3

// MARK: - Public contracts

public enum SaveChannel: String, Codable, CaseIterable, Sendable {
    case story = "chat"
    case `private` = "private"
}

public enum SaveStoreError: Error, LocalizedError, Sendable {
    case invalidChannel(String)
    case invalidChatID
    case invalidPayload(String)
    case legacyFlatDocumentRequiresFullSave
    case sqlite(String)
    case filesystem(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidChannel(let value): return "unknown save channel: \(value) (want chat|private)"
        case .invalidChatID: return "invalid chat id"
        case .invalidPayload(let value): return value
        case .legacyFlatDocumentRequiresFullSave: return "legacy flat save; use mode=full once"
        case .sqlite(let value): return "SQLite error: \(value)"
        case .filesystem(let value): return "Filesystem error: \(value)"
        case .decoding(let value): return "JSON decoding error: \(value)"
        }
    }
}

public struct SaveOperationResult: Codable, Sendable {
    public var status: String
    public var message: String?
    public var code: String?
    public var path: String?
    public var mode: String?
    public var messageCount: Int?
    public var patched: Int?
    public var deleted: Int?
    public var messageID: String?
    public var createdAt: Int64?
    public var deduped: Bool?
    public var role: String?
    public var kind: String?
    public var updated: Int?
    public var recalled: Bool?
    public var imageName: String?
    public var hasMore: Bool?

    public init(status: String = "ok") { self.status = status }

    public static func error(_ message: String, code: String? = nil) -> Self {
        var result = Self(status: "error")
        result.message = message
        result.code = code
        return result
    }
}

public struct SaveWindow: Codable, Sendable {
    public var messages: [[String: JSONValue]]
    public var hasMore: Bool
    public init(messages: [[String: JSONValue]], hasMore: Bool) {
        self.messages = messages
        self.hasMore = hasMore
    }
}

public indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var objectValue: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    public var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    public var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    public var intValue: Int64? { if case .integer(let v) = self { return v }; return nil }
    public subscript(_ key: String) -> JSONValue? { objectValue?[key] }
}

public protocol SaveStore: Sendable {
    var channel: SaveChannel { get }
    func upsert(message: [String: JSONValue]?, messages: [[String: JSONValue]]?, meta: [String: JSONValue]?, context: [String: JSONValue]) async throws -> SaveOperationResult
    func loadWindow(limit: Int, before: JSONValue?, context: [String: JSONValue]) async throws -> [String: JSONValue]
    func patchMeta(_ meta: [String: JSONValue], context: [String: JSONValue]) async throws -> SaveOperationResult
}

public struct SavePersistenceConfiguration: Sendable {
    public var rootDirectory: URL
    public var environment: [String: String]
    public init(rootDirectory: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.environment = environment
    }
}

public final class SaveWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var forcedValue: Bool?
    private let environment: @Sendable () -> [String: String]
    public init(environment: @escaping @Sendable () -> [String: String] = { ProcessInfo.processInfo.environment }) {
        self.environment = environment
    }
    public func setDisabled(_ value: Bool?) { lock.lock(); forcedValue = value; lock.unlock() }
    public func isDisabled() -> Bool {
        lock.lock(); let forced = forcedValue; lock.unlock()
        if let forced { return forced }
        let value = environment()["SAVE_DISABLED"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return ["1", "true", "yes"].contains(value)
    }
    public func disabledResponse(channel: String) -> SaveOperationResult {
        .error("存档写入已关闭（SAVE_DISABLED，channel=\(channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "?" : channel)）— 用于确认请求只走 services/save", code: "save_disabled")
    }
}

public final class ConversationPersistence: @unchecked Sendable {
    public let configuration: SavePersistenceConfiguration
    public let writeGate: SaveWriteGate
    public init(configuration: SavePersistenceConfiguration, writeGate: SaveWriteGate = SaveWriteGate()) {
        self.configuration = configuration
        self.writeGate = writeGate
    }
    public func store(for rawChannel: String) throws -> any SaveStore {
        let value = rawChannel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let channel = SaveChannel(rawValue: value) else { throw SaveStoreError.invalidChannel(rawChannel) }
        switch channel {
        case .story: return StorySaveStore(configuration: configuration, writeGate: writeGate)
        case .private: return PrivateSaveStore(configuration: configuration, writeGate: writeGate)
        }
    }
}

extension NSLock {
    fileprivate func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }; return try body()
    }
}

extension JSONValue {
    fileprivate static func from(_ value: Any) -> JSONValue {
        if value is NSNull { return .null }
        if let v = value as? String { return .string(v) }
        if let v = value as? NSNumber {
            if CFGetTypeID(v) == CFBooleanGetTypeID() { return .bool(v.boolValue) }
            if String(cString: v.objCType) == "d" || String(cString: v.objCType) == "f" { return .number(v.doubleValue) }
            return .integer(v.int64Value)
        }
        if let v = value as? [Any] { return .array(v.map(JSONValue.from)) }
        if let v = value as? [String: Any] { return .object(v.mapValues(JSONValue.from)) }
        return .null
    }
    fileprivate var foundationValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return NSNumber(value: v)
        case .integer(let v): return NSNumber(value: v)
        case .number(let v): return NSNumber(value: v)
        case .string(let v): return v
        case .array(let v): return v.map(\.foundationValue)
        case .object(let v): return v.mapValues(\.foundationValue)
        }
    }
}

import CoreFoundation
