import Foundation
import CoreFoundation

/// JSON-compatible value used by the mailbox persistence layer.
public indirect enum MailboxJSONValue: Codable, Sendable, Equatable {
    case object([String: MailboxJSONValue])
    case array([MailboxJSONValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: MailboxJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([MailboxJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "JSON numbers must be finite"))
            }
            try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public static func fromFoundation(_ value: Any) throws -> MailboxJSONValue {
        if value is NSNull { return .null }
        if let value = value as? String { return .string(value) }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            let double = value.doubleValue
            if double.isFinite, double.rounded(.towardZero) == double, double >= Double(Int64.min), double < 9_223_372_036_854_775_808.0 {
                return .integer(value.int64Value)
            }
            return .number(double)
        }
        if let value = value as? [String: Any] {
            var result: [String: MailboxJSONValue] = [:]
            for (key, item) in value { result[key] = try fromFoundation(item) }
            return .object(result)
        }
        if let value = value as? [Any] {
            return .array(try value.map { try fromFoundation($0) })
        }
        throw MailboxServiceError.unsupportedJSONValue(String(describing: type(of: value)))
    }

    public var foundationValue: Any {
        switch self {
        case .object(let value): return value.mapValues(\.foundationValue)
        case .array(let value): return value.map(\.foundationValue)
        case .string(let value): return value
        case .integer(let value): return NSNumber(value: value)
        case .number(let value): return NSNumber(value: value)
        case .bool(let value): return NSNumber(value: value)
        case .null: return NSNull()
        }
    }

    public var objectValue: [String: MailboxJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [MailboxJSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Python-style truthiness for the JSON value types used by mailbox.py.
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

    /// Converts numeric timestamps to Int64 when the value is exactly integral.
    public var integerLike: Int64? {
        switch self {
        case .integer(let value): return value
        case .number(let value): return Int64(exactly: value)
        case .string(let value): return Int64(value)
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    public var pythonStringOrEmpty: String {
        guard isTruthy else { return "" }
        return stringValue ?? ""
    }
}

public typealias MailboxRecord = [String: MailboxJSONValue]
