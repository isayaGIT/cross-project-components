import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Utilities and transport for converting Anthropic Messages API behavior
/// into an OpenAI-compatible chat completion interface.
public enum AnthropicMessages {
    public static let anthropicVersion = "2023-06-01"
    public static let defaultTimeout: TimeInterval = 60
    public static let defaultRetries = 2

    private static let volatileMarkers = [
        "【召回的记忆】",
        "【张平今天的生活",
        "【最近发生的对话】",
        "【本频道最近对话】",
        "【陪伴频道",
        "【当前时间】"
    ]

    public enum ClientError: Error, LocalizedError {
        case missingMessagesURL(label: String)
        case invalidURL(String)
        case invalidResponse
        case httpFailure(status: Int, body: String)
        case retriesExhausted(label: String, reason: String)
        case invalidJSON(String)

        public var errorDescription: String? {
            switch self {
            case .missingMessagesURL(let label):
                return "[\(label)] 未配置 Messages API URL"
            case .invalidURL(let value):
                return "Invalid Anthropic Messages API URL: \(value)"
            case .invalidResponse:
                return "The Anthropic server returned an invalid HTTP response."
            case .httpFailure(let status, let body):
                return body.isEmpty ? "Anthropic upstream HTTP \(status)" : "Anthropic upstream HTTP \(status): \(body)"
            case .retriesExhausted(let label, let reason):
                return "LLM[\(label)] Anthropic upstream failed after retries: \(reason)"
            case .invalidJSON(let reason):
                return "Invalid JSON response: \(reason)"
            }
        }
    }

    /// Configuration fields compatible with the Python backend's cfg dictionary.
    public struct Configuration: Sendable {
        public var apiURL: String
        public var apiKey: String
        public var model: String

        public init(apiURL: String, apiKey: String = "", model: String = "") {
            self.apiURL = apiURL
            self.apiKey = apiKey
            self.model = model
        }

        public init(dictionary: [String: Any]) {
            self.apiURL = dictionary["apiUrl"] as? String ?? ""
            self.apiKey = dictionary["apiKey"] as? String ?? ""
            self.model = dictionary["model"] as? String ?? ""
        }
    }

    public struct RequestOptions: Sendable {
        public var temperature: Double
        public var maxTokens: Int
        public var stream: Bool
        public var timeout: TimeInterval
        public var retries: Int

        public init(
            temperature: Double = 0.8,
            maxTokens: Int = 1024,
            stream: Bool = false,
            timeout: TimeInterval = AnthropicMessages.defaultTimeout,
            retries: Int = AnthropicMessages.defaultRetries
        ) {
            self.temperature = temperature
            self.maxTokens = maxTokens
            self.stream = stream
            self.timeout = timeout
            self.retries = max(0, retries)
        }
    }

    public struct HTTPResult: Sendable {
        public let data: Data
        public let statusCode: Int
        public let apiURL: String
        public let model: String
        public let startedAt: Date
        public let lastError: String

        public init(data: Data, statusCode: Int, apiURL: String, model: String, startedAt: Date, lastError: String) {
            self.data = data
            self.statusCode = statusCode
            self.apiURL = apiURL
            self.model = model
            self.startedAt = startedAt
            self.lastError = lastError
        }
    }

    public struct Usage: Codable, Sendable, Equatable {
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

        public var dictionary: [String: Any] {
            var result: [String: Any] = [
                "prompt_tokens": promptTokens,
                "completion_tokens": completionTokens,
                "prompt_cache_hit_tokens": promptCacheHitTokens,
                "prompt_cache_miss_tokens": promptCacheMissTokens,
                "cache_read_input_tokens": cacheReadInputTokens,
                "cache_creation_input_tokens": cacheCreationInputTokens,
                "input_tokens": inputTokens,
                "output_tokens": outputTokens,
                "thinking_tokens": thinkingTokens
            ]
            if thinkingTokens != 0 {
                result["output_tokens_details"] = ["thinking_tokens": thinkingTokens]
            }
            return result
        }
    }

    /// Returns true when a model identifier refers to Claude or Anthropic.
    public static func isClaudeModel(_ model: String?) -> Bool {
        let value = (model ?? "").lowercased()
        return value.contains("claude") || value.contains("anthropic")
    }

    /// Derives a Messages API endpoint from a configured chat completion URL.
    public static func normalizeMessagesURL(_ apiURL: String?) -> String {
        let value = (apiURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard !value.isEmpty else { return "" }
        if value.hasSuffix("/v1/messages") { return value }
        if value.hasSuffix("/chat/completions") {
            return String(value.dropLast("/chat/completions".count)) + "/messages"
        }
        if value.hasSuffix("/v1/chat") {
            return String(value.dropLast("/chat".count)) + "/messages"
        }
        if value.hasSuffix("/v1") { return value + "/messages" }
        return value + "/v1/messages"
    }

    /// Splits a system prompt into stable and volatile sections for prompt caching.
    public static func splitSystemForCache(_ content: String?) -> (stable: String, volatile: String) {
        guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ("", "")
        }
        var earliest = content.endIndex
        for marker in volatileMarkers {
            if let index = content.range(of: marker)?.lowerBound, index < earliest {
                earliest = index
            }
        }
        guard earliest < content.endIndex else {
            return (content.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }
        let stable = String(content[..<earliest]).trimmingCharacters(in: .whitespacesAndNewlines)
        let volatile = String(content[earliest...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (stable, volatile)
    }

    private static func textBlock(_ text: String, cache: Bool = false) -> [String: Any] {
        var block: [String: Any] = ["type": "text", "text": text]
        if cache { block["cache_control"] = ["type": "ephemeral"] }
        return block
    }

    /// Converts OpenAI-style messages into an Anthropic Messages API request body.
    /// Consecutive leading system messages are merged, with a cache breakpoint
    /// after the stable section when one can be identified.
    public static func buildMessagesRequest(
        model: String,
        messages: [[String: Any]],
        temperature: Double = 0.8,
        maxTokens: Int = 1024,
        stream: Bool = false
    ) -> [String: Any] {
        var systemParts: [String] = []
        var index = 0
        while index < messages.count {
            let message = messages[index]
            guard message["role"] as? String == "system" else { break }
            let content = (message["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { systemParts.append(content) }
            index += 1
        }

        let systemText = systemParts.joined(separator: "\n\n")
        let split = splitSystemForCache(systemText)
        var systemBlocks: [[String: Any]] = []
        if !split.stable.isEmpty { systemBlocks.append(textBlock(split.stable, cache: true)) }
        if !split.volatile.isEmpty { systemBlocks.append(textBlock(split.volatile)) }

        var anthropicMessages: [[String: Any]] = []
        if index < messages.count {
            for message in messages[index...] {
                guard let role = message["role"] as? String, role == "user" || role == "assistant" else { continue }
                let content: String
                if let value = message["content"] as? String {
                    content = value
                } else if let value = message["content"], !(value is NSNull) {
                    content = String(describing: value)
                } else {
                    content = ""
                }
                anthropicMessages.append([
                    "role": role,
                    "content": [["type": "text", "text": content]]
                ])
            }
        }

        if anthropicMessages.isEmpty {
            anthropicMessages.append([
                "role": "user",
                "content": [["type": "text", "text": "请根据以上设定与对话上下文回复。"]]
            ])
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": anthropicMessages
        ]
        if !systemBlocks.isEmpty { body["system"] = systemBlocks }
        if stream { body["stream"] = true }
        return body
    }

    /// Produces HTTP headers compatible with the original Anthropic proxy.
    public static func headers(apiKey: String) -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "text/event-stream, application/json",
            "anthropic-version": anthropicVersion,
            "x-api-key": apiKey,
            "Authorization": "Bearer \(apiKey)"
        ]
    }

    /// Sends a request to Anthropic with bounded retries for server errors and
    /// transport failures. As in the Python implementation, HTTP statuses below
    /// 500 are returned to the caller without retrying.
    public static func openMessages(
        configuration: Configuration,
        body: [String: Any],
        label: String,
        options: RequestOptions = RequestOptions(),
        session: URLSession = .shared
    ) async throws -> HTTPResult {
        let apiURL = normalizeMessagesURL(configuration.apiURL)
        guard !apiURL.isEmpty else { throw ClientError.missingMessagesURL(label: label) }
        guard let url = URL(string: apiURL), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http", url.host != nil else {
            throw ClientError.invalidURL(apiURL)
        }

        let model = (body["model"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? configuration.model
        var payload = body
        payload["model"] = model
        let requestBody: Data
        do {
            requestBody = try JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed])
        } catch {
            throw ClientError.invalidJSON(error.localizedDescription)
        }

        let startedAt = Date()
        var lastError = ""
        for attempt in 0...options.retries {
            var request = URLRequest(url: url, timeoutInterval: options.timeout)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            for (key, value) in headers(apiKey: configuration.apiKey) {
                request.setValue(value, forHTTPHeaderField: key)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
                if (200..<300).contains(http.statusCode) || http.statusCode < 500 {
                    return HTTPResult(data: data, statusCode: http.statusCode, apiURL: apiURL, model: model, startedAt: startedAt, lastError: lastError)
                }
                let bodyText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                lastError = "upstream HTTP \(http.statusCode)" + (bodyText.isEmpty ? "" : " | " + String(bodyText.replacingOccurrences(of: "\n", with: " ").prefix(300)))
            } catch {
                if let clientError = error as? ClientError, case .invalidResponse = clientError {
                    throw clientError
                }
                lastError = error.localizedDescription
            }

            if attempt < options.retries {
                let delay = 0.6 * Double(attempt + 1)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw ClientError.retriesExhausted(label: label, reason: String(lastError.prefix(400)))
    }

    private static func integer(_ value: Any?) -> Int {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let result = Int(string) { return result }
        return 0
    }

    private static func thinkingTokens(from usage: [String: Any]) -> Int {
        if let details = usage["output_tokens_details"] as? [String: Any] {
            let value = integer(details["thinking_tokens"])
            if value != 0 { return value }
        }
        for key in ["thinking_tokens", "reasoning_tokens"] {
            let value = integer(usage[key])
            if value != 0 { return value }
        }
        return 0
    }

    /// Converts Anthropic usage fields into the OpenAI-compatible usage schema.
    public static func anthropicUsageToOpenAI(_ usage: [String: Any]?) -> Usage {
        let value = usage ?? [:]
        let input = integer(value["input_tokens"])
        let output = integer(value["output_tokens"])
        let cacheRead = integer(value["cache_read_input_tokens"])
        let cacheCreation = integer(value["cache_creation_input_tokens"])
        return Usage(
            promptTokens: input + cacheRead + cacheCreation,
            completionTokens: output,
            promptCacheHitTokens: cacheRead,
            promptCacheMissTokens: input + cacheCreation,
            cacheReadInputTokens: cacheRead,
            cacheCreationInputTokens: cacheCreation,
            inputTokens: input,
            outputTokens: output,
            thinkingTokens: thinkingTokens(from: value)
        )
    }

    /// Converts a non-streaming Anthropic JSON response to an OpenAI chat completion.
    public static func convertJSONResponseToOpenAI(_ raw: Data) throws -> Data {
        let value: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
                throw ClientError.invalidJSON("Expected a JSON object")
            }
            value = object
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.invalidJSON(error.localizedDescription)
        }

        var textParts: [String] = []
        if let content = value["content"] as? [[String: Any]] {
            for block in content where block["type"] as? String == "text" {
                textParts.append(block["text"] as? String ?? "")
            }
        }
        let usage = anthropicUsageToOpenAI(value["usage"] as? [String: Any])
        let completion: [String: Any] = [
            "id": (value["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "anthropic-proxy",
            "object": "chat.completion",
            "model": value["model"] as? String ?? "",
            "choices": [[
                "index": 0,
                "message": ["role": "assistant", "content": textParts.joined()],
                "finish_reason": (value["stop_reason"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "stop"
            ]],
            "usage": usage.dictionary
        ]
        do {
            return try JSONSerialization.data(withJSONObject: completion, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            throw ClientError.invalidJSON(error.localizedDescription)
        }
    }

    private static func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys])
    }

    private static func openAIChunk(content: String = "", finish: Bool = false, usage: Usage? = nil) throws -> Data {
        if finish && content.isEmpty && usage == nil {
            return Data("data: [DONE]\n\n".utf8)
        }
        var payload: [String: Any] = [
            "object": "chat.completion.chunk",
            "choices": [[
                "index": 0,
                "delta": finish ? [:] as [String: Any] : ["content": content],
                "finish_reason": finish ? "stop" : NSNull()
            ]]
        ]
        if let usage { payload["usage"] = usage.dictionary }
        var result = Data("data: ".utf8)
        result.append(try jsonData(payload))
        result.append(Data("\n\n".utf8))
        if finish { result.append(Data("data: [DONE]\n\n".utf8)) }
        return result
    }

    /// Converts complete or partial Anthropic SSE data into OpenAI SSE frames.
    /// The caller supplies successive byte chunks and retains the returned buffer
    /// between calls. Set `isFinal` to true to process a final unterminated line
    /// and emit the terminal completion frame.
    public struct StreamConverter: Sendable {
        private var buffer = Data()
        private var eventName = ""
        private var accumulatedUsage: [String: Any] = [:]
        private var sentRole = false
        private var finished = false

        public init() {}

        public mutating func append(_ bytes: Data, isFinal: Bool = false) throws -> (output: Data, usage: Usage?) {
            guard !finished else { return (Data(), nil) }
            buffer.append(bytes)
            var output = Data()

            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                try processLine(Data(lineData), into: &output)
            }

            if isFinal {
                if !buffer.isEmpty {
                    try processLine(buffer, into: &output)
                    buffer.removeAll(keepingCapacity: false)
                }
                let usage = AnthropicMessages.anthropicUsageToOpenAI(accumulatedUsage)
                let includeUsage = usage.promptTokens != 0 || usage.completionTokens != 0
                output.append(try AnthropicMessages.openAIChunk(finish: true, usage: includeUsage ? usage : nil))
                finished = true
                return (output, usage)
            }
            return (output, nil)
        }

        private mutating func processLine(_ rawLine: Data, into output: inout Data) throws {
            guard let decoded = String(data: rawLine, encoding: .utf8) else { return }
            let line = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                eventName = ""
                return
            }
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }
            guard line.hasPrefix("data:") else { return }
            let dataString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !dataString.isEmpty, let data = dataString.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let event = object as? [String: Any] else { return }
            let type = event["type"] as? String ?? eventName

            switch type {
            case "message_start":
                if let message = event["message"] as? [String: Any], let usage = message["usage"] as? [String: Any] {
                    mergeUsage(usage)
                }
                if !sentRole {
                    output.append(try AnthropicMessages.openAIChunk())
                    sentRole = true
                }
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String, !text.isEmpty {
                    output.append(try AnthropicMessages.openAIChunk(content: text))
                }
            case "message_delta":
                if let usage = event["usage"] as? [String: Any] { mergeUsage(usage) }
            default:
                break
            }
        }

        private mutating func mergeUsage(_ newValues: [String: Any]) {
            for (key, value) in newValues {
                if let incoming = value as? [String: Any], var existing = accumulatedUsage[key] as? [String: Any] {
                    for (nestedKey, nestedValue) in incoming { existing[nestedKey] = nestedValue }
                    accumulatedUsage[key] = existing
                } else {
                    accumulatedUsage[key] = value
                }
            }
        }
    }

    /// Convenience conversion for a complete SSE payload. For network streaming,
    /// feed each received chunk to `StreamConverter.append` and write each returned
    /// output chunk immediately.
    public static func convertStreamToOpenAI(_ raw: Data) throws -> (data: Data, usage: Usage) {
        var converter = StreamConverter()
        let result = try converter.append(raw, isFinal: true)
        return (result.output, result.usage ?? Usage())
    }
}
