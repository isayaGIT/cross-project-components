import Foundation
import CoreFoundation

/// JSON value representation used to preserve arbitrary trace metadata safely.
public indirect enum TraceJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([TraceJSONValue])
    case object([String: TraceJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([TraceJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: TraceJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "JSON numbers must be finite"))
            }
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Converts Foundation JSON objects into the strongly typed representation.
    public init(foundationValue: Any) {
        if foundationValue is NSNull {
            self = .null
        } else if let number = foundationValue as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                let type = String(cString: number.objCType)
                if ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"].contains(type) {
                    self = .integer(number.intValue)
                } else {
                    self = .number(number.doubleValue)
                }
            }
        } else if let value = foundationValue as? String {
            self = .string(value)
        } else if let value = foundationValue as? [Any] {
            self = .array(value.map(TraceJSONValue.init(foundationValue:)))
        } else if let value = foundationValue as? [String: Any] {
            self = .object(value.mapValues(TraceJSONValue.init(foundationValue:)))
        } else {
            self = .null
        }
    }

    public var foundationValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return NSNumber(value: value)
        case .integer(let value):
            return NSNumber(value: value)
        case .number(let value):
            return value.isFinite ? NSNumber(value: value) : NSNull()
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.foundationValue)
        case .object(let values):
            return values.mapValues(\.foundationValue)
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: TraceJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [TraceJSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var integerValue: Int? {
        switch self {
        case .integer(let value): return value
        case .number(let value) where value.isFinite && value.rounded(.towardZero) == value:
            return Int(exactly: value)
        case .string(let value): return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    /// Python-compatible truthiness for the JSON types accepted by the source module.
    public var isTruthy: Bool {
        switch self {
        case .null: return false
        case .bool(let value): return value
        case .integer(let value): return value != 0
        case .number(let value): return value != 0 && !value.isNaN
        case .string(let value): return !value.isEmpty
        case .array(let value): return !value.isEmpty
        case .object(let value): return !value.isEmpty
        }
    }
}

public struct DebugTraceUsage: Codable, Equatable, Sendable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var promptCacheHitTokens: Int
    public var promptCacheMissTokens: Int
    public var cacheReadInputTokens: Int
    public var cacheCreationInputTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var thinkingTokens: Int

    public init(
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        promptCacheHitTokens: Int = 0,
        promptCacheMissTokens: Int = 0,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        thinkingTokens: Int = 0
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.promptCacheHitTokens = promptCacheHitTokens
        self.promptCacheMissTokens = promptCacheMissTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.thinkingTokens = thinkingTokens
    }

    public var hasAnyTokens: Bool {
        promptTokens != 0 || completionTokens != 0 || outputTokens != 0
    }

    public var jsonValue: TraceJSONValue {
        var result: [String: TraceJSONValue] = [
            "prompt_tokens": .integer(promptTokens),
            "completion_tokens": .integer(completionTokens),
            "prompt_cache_hit_tokens": .integer(promptCacheHitTokens),
            "prompt_cache_miss_tokens": .integer(promptCacheMissTokens),
            "cache_read_input_tokens": .integer(cacheReadInputTokens),
            "cache_creation_input_tokens": .integer(cacheCreationInputTokens),
            "input_tokens": .integer(inputTokens),
            "output_tokens": .integer(outputTokens)
        ]
        if thinkingTokens != 0 {
            result["thinking_tokens"] = .integer(thinkingTokens)
            result["output_tokens_details"] = .object(["thinking_tokens": .integer(thinkingTokens)])
        }
        return .object(result)
    }
}

public struct DebugTraceRecall: Codable, Equatable, Sendable {
    public var score: TraceJSONValue?
    public var inject: Bool
    public var flash: Bool
    public var title: String
    public var source: String
    public var content: String

    public init(
        score: TraceJSONValue? = nil,
        inject: Bool = false,
        flash: Bool = false,
        title: String = "",
        source: String = "",
        content: String = ""
    ) {
        self.score = score
        self.inject = inject
        self.flash = flash
        self.title = title
        self.source = source
        self.content = content
    }

    public var jsonValue: TraceJSONValue {
        var result: [String: TraceJSONValue] = [
            "inject": .bool(inject),
            "flash": .bool(flash),
            "memory": .object([
                "title": .string(title),
                "source": .string(source),
                "content": .string(content)
            ])
        ]
        if let score { result["score"] = score }
        return .object(result)
    }
}

public struct DebugTraceRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ts: String
    public var slot: String
    public var model: String
    public var userInput: String
    public var systemPrompt: String
    public var rawOutput: String?
    public var recalls: [DebugTraceRecall]?
    public var usage: TraceJSONValue?
    public var usageSource: String?

    public init(
        id: String,
        ts: String,
        slot: String = "chat",
        model: String = "",
        userInput: String = "",
        systemPrompt: String = "",
        rawOutput: String? = nil,
        recalls: [DebugTraceRecall]? = nil,
        usage: TraceJSONValue? = nil,
        usageSource: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.slot = slot
        self.model = model
        self.userInput = userInput
        self.systemPrompt = systemPrompt
        self.rawOutput = rawOutput
        self.recalls = recalls
        self.usage = usage
        self.usageSource = usageSource
    }

    public var jsonValue: TraceJSONValue {
        var result: [String: TraceJSONValue] = [
            "id": .string(id),
            "ts": .string(ts),
            "slot": .string(slot),
            "model": .string(model),
            "userInput": .string(userInput),
            "systemPrompt": .string(systemPrompt)
        ]
        if let rawOutput { result["rawOutput"] = .string(rawOutput) }
        if let recalls { result["recalls"] = .array(recalls.map(\.jsonValue)) }
        if let usage { result["usage"] = usage }
        if let usageSource { result["usageSource"] = .string(usageSource) }
        return .object(result)
    }
}

public struct DebugTraceCollection: Codable, Equatable, Sendable {
    public var recent: [TraceJSONValue]
    public var pinned: [TraceJSONValue]
    public var recentMax: Int

    public init(recent: [TraceJSONValue], pinned: [TraceJSONValue], recentMax: Int) {
        self.recent = recent
        self.pinned = pinned
        self.recentMax = recentMax
    }

    public var jsonValue: TraceJSONValue {
        .object([
            "recent": .array(recent),
            "pinned": .array(pinned),
            "recentMax": .integer(recentMax)
        ])
    }
}

public struct DebugTraceUsageEstimate: Equatable, Sendable {
    public var usage: DebugTraceUsage
    public var source: String

    public init(usage: DebugTraceUsage, source: String) {
        self.usage = usage
        self.source = source
    }
}

public enum DebugTraceError: Error, LocalizedError, Sendable {
    case invalidJSONRoot
    case invalidPatch
    case persistence(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSONRoot: return "The trace storage root must be a JSON object."
        case .invalidPatch: return "No supported trace fields were supplied in the patch."
        case .persistence(let message): return "Unable to persist debug traces: \(message)"
        }
    }
}
