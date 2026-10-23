import Foundation

/// Constants and helpers shared by the LLM HTTP transport.
public enum LLMTransport {
    public static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

    public static let streamHeadersBase: [String: String] = [
        "Content-Type": "application/json",
        "User-Agent": browserUserAgent,
        "Accept": "*/*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "sec-ch-ua": "\"Chromium\";v=\"126\", \"Not.A.Brand\";v=\"24\", \"Google Chrome\";v=\"126\"",
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": "\"macOS\"",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "cross-site"
    ]

    private static let v4ModelHints = ["deepseek-v4", "v4-flash", "v4-pro"]

    /// Detects models that require thinking to be explicitly disabled.
    public static func isV4Model(_ model: String?) -> Bool {
        let normalized = (model ?? "").lowercased()
        return v4ModelHints.contains { normalized.contains($0) }
    }

    /// Normalizes a provider base URL to its OpenAI-compatible chat completion endpoint.
    public static func normalizeChatURL(_ apiURL: String?) -> String? {
        guard let apiURL else { return nil }
        let url = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !url.isEmpty else { return apiURL }
        if url.hasSuffix("/chat/completions") { return url }
        if url.hasSuffix("/chat") { return url + "/completions" }
        if url.hasSuffix("/v1") { return url + "/chat/completions" }
        return url + "/v1/chat/completions"
    }

    /// Extracts the assistant's visible answer. Reasoning fields are never treated as content.
    public static func extractContent(from result: [String: Any]) throws -> String {
        guard
            let choices = result["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw LLMTransportError.invalidResponse("Missing choices[0].message")
        }
        return ((message["content"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A message sent to an OpenAI-compatible chat completion endpoint.
public struct LLMChatMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Configuration for a single upstream provider.
public struct LLMTransportConfiguration: Sendable {
    public var apiURL: String
    public var model: String
    public var apiKey: String

    public init(apiURL: String, model: String, apiKey: String) {
        self.apiURL = apiURL
        self.model = model
        self.apiKey = apiKey
    }
}

/// Token usage returned by an OpenAI-compatible API.
public struct LLMTokenUsage: Codable, Sendable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int

    public init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

/// Successful non-streaming chat completion.
public struct LLMChatResult: Sendable {
    public let content: String
    public let usage: LLMTokenUsage
    /// Original decoded JSON response, retained for provider-specific fields.
    public let raw: [String: Any]

    public init(content: String, usage: LLMTokenUsage, raw: [String: Any]) {
        self.content = content
        self.usage = usage
        self.raw = raw
    }
}

public enum LLMTransportError: Error, LocalizedError {
    case missingAPIURL(label: String)
    case invalidAPIKey(label: String, reason: String)
    case invalidResponse(String)
    case emptyContent
    case httpStatus(code: Int, body: String)
    case networkRetriesExhausted(label: String, attempts: Int, underlying: String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIURL(let label):
            return "[\(label)] 未配置 API URL"
        case .invalidAPIKey(let label, let reason):
            return "[\(label)] \(reason)"
        case .invalidResponse(let reason):
            return "Invalid LLM response: \(reason)"
        case .emptyContent:
            return "模型返回空 content（reasoning 模型可能把 token 全花在思考上）"
        case .httpStatus(let code, let body):
            return "LLM upstream returned HTTP \(code): \(body)"
        case .networkRetriesExhausted(let label, let attempts, let underlying):
            return "LLM[\(label)] after \(attempts) attempts: \(underlying)"
        case .invalidConfiguration(let reason):
            return "Invalid LLM transport configuration: \(reason)"
        }
    }
}

/// Records successful or failed calls. Implement this protocol to connect the transport
/// to an application's existing telemetry and cost-accounting system.
public protocol LLMTransportTelemetry: Sendable {
    func record(label: String, model: String, apiURL: String, promptTokens: Int, completionTokens: Int, elapsed: TimeInterval, succeeded: Bool, cacheHitTokens: Int?, cacheMissTokens: Int?) async
}

/// Optional API-key validation hook, allowing the routing layer to enforce its own key policy.
public protocol LLMAPIKeyValidating: Sendable {
    func validationProblem(for apiKey: String) -> String?
}

public struct PermissiveLLMAPIKeyValidator: LLMAPIKeyValidating {
    public init() {}

    public func validationProblem(for apiKey: String) -> String? {
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未配置 API Key" : nil
    }
}

/// Centralized non-streaming LLM HTTP transport. Business code should call this abstraction
/// rather than creating provider-specific chat completion requests independently.
public struct LLMHTTPTransport: Sendable {
    private let session: URLSession
    private let telemetry: (any LLMTransportTelemetry)?
    private let keyValidator: any LLMAPIKeyValidating

    public init(session: URLSession = .shared, telemetry: (any LLMTransportTelemetry)? = nil, keyValidator: any LLMAPIKeyValidating = PermissiveLLMAPIKeyValidator()) {
        self.session = session
        self.telemetry = telemetry
        self.keyValidator = keyValidator
    }

    /// Sends a chat completion request and returns its visible content, token counts and raw JSON.
    ///
    /// `extraBody` values override generated fields, matching the Python implementation's update
    /// order. Set `retries` to the number of additional attempts after the initial request.
    public func postChat(
        configuration: LLMTransportConfiguration,
        label: String,
        messages: [LLMChatMessage],
        temperature: Double = 0.8,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 180,
        retries: Int = 2,
        extraBody: [String: Any] = [:]
    ) async throws -> LLMChatResult {
        guard let endpoint = LLMTransport.normalizeChatURL(configuration.apiURL), !endpoint.isEmpty else {
            throw LLMTransportError.missingAPIURL(label: label)
        }
        guard let url = URL(string: endpoint), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
            throw LLMTransportError.invalidConfiguration("API URL must be a valid HTTP or HTTPS URL")
        }
        if let problem = keyValidator.validationProblem(for: configuration.apiKey) {
            throw LLMTransportError.invalidAPIKey(label: label, reason: problem)
        }
        guard timeout > 0 else {
            throw LLMTransportError.invalidConfiguration("timeout must be greater than zero")
        }
        guard retries >= 0 else {
            throw LLMTransportError.invalidConfiguration("retries must not be negative")
        }
        guard maxTokens >= 0 else {
            throw LLMTransportError.invalidConfiguration("maxTokens must not be negative")
        }

        var body: [String: Any] = [
            "model": configuration.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        if LLMTransport.isV4Model(configuration.model) {
            body["thinking"] = ["type": "disabled"]
        }
        for (key, value) in extraBody {
            body[key] = value
        }
        let encodedBody: Data
        do {
            encodedBody = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            throw LLMTransportError.invalidConfiguration("Request body is not valid JSON: \(error.localizedDescription)")
        }

        var lastError: Error?
        for attempt in 0...retries {
            let startedAt = Date()
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.httpBody = encodedBody
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(LLMTransport.browserUserAgent, forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startedAt)
                guard let http = response as? HTTPURLResponse else {
                    throw LLMTransportError.invalidResponse("Response is not HTTP")
                }
                guard (200..<300).contains(http.statusCode) else {
                    let bodyText = String(data: data.prefix(300), encoding: .utf8) ?? ""
                    throw LLMTransportError.httpStatus(code: http.statusCode, body: bodyText)
                }
                let decoded = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                guard let result = decoded as? [String: Any] else {
                    throw LLMTransportError.invalidResponse("Expected a JSON object")
                }
                let content = try LLMTransport.extractContent(from: result)
                let usageObject = result["usage"] as? [String: Any] ?? [:]
                let prompt = Self.integerValue(usageObject["prompt_tokens"])
                let completion = Self.integerValue(usageObject["completion_tokens"])
                await telemetry?.record(
                    label: label,
                    model: configuration.model,
                    apiURL: endpoint,
                    promptTokens: prompt,
                    completionTokens: completion,
                    elapsed: elapsed,
                    succeeded: true,
                    cacheHitTokens: Self.optionalIntegerValue(usageObject["prompt_cache_hit_tokens"]),
                    cacheMissTokens: Self.optionalIntegerValue(usageObject["prompt_cache_miss_tokens"])
                )
                guard !content.isEmpty else {
                    throw LLMTransportError.emptyContent
                }
                return LLMChatResult(
                    content: content,
                    usage: LLMTokenUsage(promptTokens: prompt, completionTokens: completion),
                    raw: result
                )
            } catch {
                lastError = error
                let elapsed = Date().timeIntervalSince(startedAt)
                let isRetryable: Bool
                if let transportError = error as? URLError {
                    isRetryable = Self.isRetryable(transportError.code)
                } else if let transportError = error as? LLMTransportError {
                    if case .httpStatus(let code, _) = transportError {
                        isRetryable = code >= 500
                    } else {
                        isRetryable = false
                    }
                } else {
                    isRetryable = false
                }

                if !isRetryable {
                    await telemetry?.record(
                        label: label,
                        model: configuration.model,
                        apiURL: endpoint,
                        promptTokens: 0,
                        completionTokens: 0,
                        elapsed: elapsed,
                        succeeded: false,
                        cacheHitTokens: nil,
                        cacheMissTokens: nil
                    )
                    throw error
                }
                if attempt == retries {
                    await telemetry?.record(
                        label: label,
                        model: configuration.model,
                        apiURL: endpoint,
                        promptTokens: 0,
                        completionTokens: 0,
                        elapsed: elapsed,
                        succeeded: false,
                        cacheHitTokens: nil,
                        cacheMissTokens: nil
                    )
                    throw LLMTransportError.networkRetriesExhausted(
                        label: label,
                        attempts: retries + 1,
                        underlying: error.localizedDescription
                    )
                }
            }
        }
        throw LLMTransportError.networkRetriesExhausted(
            label: label,
            attempts: retries + 1,
            underlying: lastError?.localizedDescription ?? "Unknown transport error"
        )
    }

    private static func integerValue(_ value: Any?) -> Int {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return 0
    }

    private static func optionalIntegerValue(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return nil
    }

    private static func isRetryable(_ code: URLError.Code) -> Bool {
        switch code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .networkConnectionLost, .notConnectedToInternet, .resourceUnavailable,
             .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
