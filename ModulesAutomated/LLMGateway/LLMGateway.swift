import Foundation
import CryptoKit

/// Configuration required to route a request to an upstream language model.
/// The field names preserve the source Python gateway's public configuration contract.
public struct LLMGatewayConfiguration: Sendable {
    public let apiURL: String
    public let model: String
    public let apiKey: String

    public init(apiURL: String, model: String, apiKey: String) {
        self.apiURL = apiURL
        self.model = model
        self.apiKey = apiKey
    }

    /// Builds a configuration from the source-compatible dictionary representation.
    public init(dictionary: [String: Any]) throws {
        guard let apiURL = dictionary["apiUrl"] as? String,
              let model = dictionary["model"] as? String,
              let apiKey = dictionary["apiKey"] as? String else {
            throw LLMGatewayError.invalidConfiguration
        }
        self.init(apiURL: apiURL, model: model, apiKey: apiKey)
    }

    public var dictionary: [String: Any] {
        ["apiUrl": apiURL, "model": model, "apiKey": apiKey]
    }
}

/// JSON-compatible values accepted by the gateway and transport.
/// Use this type when callers want compile-time Sendable guarantees for message bodies.
public indirect enum LLMGatewayJSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([LLMGatewayJSONValue])
    case object([String: LLMGatewayJSONValue])

    fileprivate var foundationValue: Any {
        switch self {
        case .null: NSNull()
        case .bool(let value): value
        case .integer(let value): NSNumber(value: value)
        case .number(let value): NSNumber(value: value)
        case .string(let value): value
        case .array(let values): values.map(\.foundationValue)
        case .object(let values): values.mapValues(\.foundationValue)
        }
    }

    fileprivate static func from(_ value: Any) -> LLMGatewayJSONValue? {
        if value is NSNull { return .null }
        if let value = value as? String { return .string(value) }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            if String(cString: value.objCType).contains("f") || String(cString: value.objCType).contains("d") {
                return .number(value.doubleValue)
            }
            return .integer(value.int64Value)
        }
        if let values = value as? [Any] {
            let converted = values.compactMap(from)
            guard converted.count == values.count else { return nil }
            return .array(converted)
        }
        if let values = value as? [String: Any] {
            var converted: [String: LLMGatewayJSONValue] = [:]
            for (key, item) in values {
                guard let result = from(item) else { return nil }
                converted[key] = result
            }
            return .object(converted)
        }
        return nil
    }
}

import CoreFoundation

/// A chat message passed through the gateway.
public struct LLMGatewayMessage: Sendable, Equatable {
    public var role: String
    public var content: LLMGatewayJSONValue

    public init(role: String, content: LLMGatewayJSONValue) {
        self.role = role
        self.content = content
    }

    public init(role: String, content: String) {
        self.init(role: role, content: .string(content))
    }

    fileprivate var dictionary: [String: Any] {
        ["role": role, "content": content.foundationValue]
    }
}

/// Typed errors emitted by the gateway.
public enum LLMGatewayError: Error, LocalizedError, Sendable {
    case missingLabel
    case missingTaskKeyOrConfiguration
    case missingTaskKey
    case invalidConfiguration
    case invalidMessages(String)
    case idempotencyWaitTimedOut(keyPrefix: String)

    public var errorDescription: String? {
        switch self {
        case .missingLabel:
            return "LLM gateway requires a non-empty label."
        case .missingTaskKeyOrConfiguration:
            return "LLM call requires either a task key or an explicit configuration."
        case .missingTaskKey:
            return "LLM chat requires a task key."
        case .invalidConfiguration:
            return "LLM configuration must contain string apiUrl, model, and apiKey fields."
        case .invalidMessages(let reason):
            return "Invalid LLM messages: \(reason)"
        case .idempotencyWaitTimedOut(let keyPrefix):
            return "LLM idempotency wait timed out for key \(keyPrefix)…"
        }
    }
}

/// Abstracts the existing routing subsystem.
public protocol LLMGatewayRouting: Sendable {
    func resolve(taskKey: String) async throws -> LLMGatewayConfiguration
}

/// Abstracts the existing centralized HTTP transport.
/// Implementations should delegate to the project's LLMTransport module.
public protocol LLMGatewayTransport: Sendable {
    func postChat(
        configuration: LLMGatewayConfiguration,
        label: String,
        messages: [[String: Any]],
        temperature: Double,
        maxTokens: Int,
        timeout: TimeInterval,
        retries: Int,
        extraBody: [String: Any]?
    ) async throws -> Any
}

/// Central non-streaming LLM gateway, mirroring cloud/llm/gateway.py.
/// All upstream requests pass through the injected transport. Requests sharing an
/// idempotency key while in flight await one operation and receive its result or error.
public actor LLMGateway {
    public static let jsonSystemPrompt = "你只输出JSON，不要markdown、不要代码块、不要解释。"

    private let routing: any LLMGatewayRouting
    private let transport: any LLMGatewayTransport
    private var inFlight: [String: InFlightRequest] = [:]

    private struct InFlightRequest {
        let id: UUID
        let task: Task<Any, Error>
    }

    public init(routing: any LLMGatewayRouting, transport: any LLMGatewayTransport) {
        self.routing = routing
        self.transport = transport
    }

    /// Resolves a task key using the injected routing subsystem.
    public func resolve(_ taskKey: String) async throws -> LLMGatewayConfiguration {
        guard !taskKey.isEmpty else { throw LLMGatewayError.missingTaskKey }
        return try await routing.resolve(taskKey: taskKey)
    }

    /// Routes a request using either a task key or an already-resolved configuration.
    /// A caller-supplied idempotency key is scoped to this gateway instance, as the
    /// source implementation scopes its in-flight table to the imported Python module.
    public func call(
        label: String,
        messages: Any,
        configuration: LLMGatewayConfiguration? = nil,
        taskKey: String? = nil,
        temperature: Double = 0.8,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 180,
        retries: Int = 2,
        jsonMode: Bool = false,
        idempotencyKey: String? = nil,
        extraBody: [String: Any]? = nil
    ) async throws -> Any {
        guard !label.isEmpty else { throw LLMGatewayError.missingLabel }
        let config: LLMGatewayConfiguration
        if let configuration {
            config = configuration
        } else if let taskKey, !taskKey.isEmpty {
            config = try await routing.resolve(taskKey: taskKey)
        } else {
            throw LLMGatewayError.missingTaskKeyOrConfiguration
        }

        var normalizedMessages = try Self.normalizeMessages(messages)
        if jsonMode {
            normalizedMessages.insert(
                ["role": "system", "content": Self.jsonSystemPrompt],
                at: 0
            )
        }

        guard let key = idempotencyKey, !key.isEmpty else {
            return try await transport.postChat(
                configuration: config,
                label: label,
                messages: normalizedMessages,
                temperature: temperature,
                maxTokens: maxTokens,
                timeout: timeout,
                retries: retries,
                extraBody: extraBody
            )
        }

        if let existing = inFlight[key] {
            return try await existing.task.value
        }

        let requestID = UUID()
        let transport = self.transport
        let operation = Task<Any, Error> {
            try await transport.postChat(
                configuration: config,
                label: label,
                messages: normalizedMessages,
                temperature: temperature,
                maxTokens: maxTokens,
                timeout: timeout,
                retries: retries,
                extraBody: extraBody
            )
        }
        inFlight[key] = InFlightRequest(id: requestID, task: operation)

        do {
            let result = try await operation.value
            removeInFlight(key, requestID: requestID)
            return result
        } catch {
            removeInFlight(key, requestID: requestID)
            throw error
        }
    }

    /// Recommended business entry point: resolve by task key and use that key as label.
    public func chat(
        taskKey: String,
        messages: Any,
        temperature: Double = 0.8,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 180,
        retries: Int = 2,
        jsonMode: Bool = false,
        idempotencyKey: String? = nil
    ) async throws -> Any {
        guard !taskKey.isEmpty else { throw LLMGatewayError.missingTaskKey }
        return try await call(
            label: taskKey,
            messages: messages,
            taskKey: taskKey,
            temperature: temperature,
            maxTokens: maxTokens,
            timeout: timeout,
            retries: retries,
            jsonMode: jsonMode,
            idempotencyKey: idempotencyKey
        )
    }

    /// Compatibility entry point for callers that already have a configuration.
    public func callWithConfiguration(
        _ configuration: LLMGatewayConfiguration,
        label: String,
        messages: Any,
        temperature: Double = 0.8,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 180,
        retries: Int = 2,
        jsonMode: Bool = false,
        idempotencyKey: String? = nil,
        extraBody: [String: Any]? = nil
    ) async throws -> Any {
        try await call(
            label: label,
            messages: messages,
            configuration: configuration,
            temperature: temperature,
            maxTokens: maxTokens,
            timeout: timeout,
            retries: retries,
            jsonMode: jsonMode,
            idempotencyKey: idempotencyKey,
            extraBody: extraBody
        )
    }

    /// Computes a deterministic SHA-256 fingerprint of label, model, API URL, and messages.
    /// The API key is intentionally excluded to match the Python source.
    public static func makeIdempotencyKey(
        label: String,
        configuration: LLMGatewayConfiguration,
        messages: Any
    ) throws -> String {
        let normalized = try normalizeMessagesForFingerprint(messages)
        let object: [String: Any] = [
            "label": label,
            "model": configuration.model,
            "apiUrl": configuration.apiURL,
            "messages": normalized
        ]
        let canonical = try canonicalJSON(object)
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func removeInFlight(_ key: String, requestID: UUID) {
        if inFlight[key]?.id == requestID {
            inFlight.removeValue(forKey: key)
        }
    }

    private static func normalizeMessages(_ input: Any) throws -> [[String: Any]] {
        if let messages = input as? [[String: Any]] { return messages }
        if let messages = input as? [LLMGatewayMessage] {
            return messages.map(\.dictionary)
        }
        if let value = input as? LLMGatewayJSONValue {
            if case .array(let items) = value {
                let dictionaries = items.compactMap { item -> [String: Any]? in
                    guard case .object(let fields) = item,
                          let roleValue = fields["role"],
                          let contentValue = fields["content"],
                          case .string(let role) = roleValue else { return nil }
                    return ["role": role, "content": contentValue.foundationValue]
                }
                guard dictionaries.count == items.count else {
                    throw LLMGatewayError.invalidMessages("every array element must be a message object")
                }
                return dictionaries
            }
        }
        return [["role": "user", "content": String(describing: input)]]
    }

    private static func normalizeMessagesForFingerprint(_ input: Any) throws -> Any {
        let messages = try normalizeMessages(input)
        return messages
    }

    /// Produces recursively key-sorted JSON to approximate Python json.dumps(sort_keys=True).
    private static func canonicalJSON(_ value: Any) throws -> String {
        let normalized = try canonicalize(value)
        let data = try JSONSerialization.data(withJSONObject: normalized, options: [.fragmentsAllowed, .sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw LLMGatewayError.invalidMessages("could not encode fingerprint JSON")
        }
        return string
    }

    private static func canonicalize(_ value: Any) throws -> Any {
        if value is NSNull { return NSNull() }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number }
        if let array = value as? [Any] { return try array.map(canonicalize) }
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, item) in dictionary { result[key] = try canonicalize(item) }
            return result
        }
        return String(describing: value)
    }
}
