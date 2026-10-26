import Foundation

/// One normalized event from an OpenAI-compatible chat-completion SSE stream.
public enum LLMStreamEvent: Sendable, Equatable {
    case contentDelta(String)
    case reasoningDelta(String)
    /// Incremental tool/function-call data. Arguments are fragments and must be concatenated by index.
    case toolCallDelta(choiceIndex: Int, index: Int, id: String?, type: String?, functionName: String?, arguments: String?)
    case refusalDelta(String)
    case usage(LLMStreamUsage)
    case completed(finishReason: String?)
    /// Preserves provider-specific JSON events that do not map to a standard event.
    case raw(data: String)
    /// Preserves named SSE events when their payload does not map to a standard event.
    case providerEvent(name: String, data: String)
}

public struct LLMStreamUsage: Sendable, Equatable, Codable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let promptCacheHitTokens: Int?
    public let promptCacheMissTokens: Int?

    public init(promptTokens: Int, completionTokens: Int, promptCacheHitTokens: Int? = nil, promptCacheMissTokens: Int? = nil) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.promptCacheHitTokens = promptCacheHitTokens
        self.promptCacheMissTokens = promptCacheMissTokens
    }
}

public struct LLMStreamOptions: Sendable {
    /// Total request / inactivity timeout configured on URLRequest.
    public var timeout: TimeInterval
    /// Number of retries after the initial connection attempt. Only connection errors and HTTP 5xx are retried.
    public var retries: Int
    /// Linear retry delay base, matching the Python stream module (0.6 seconds).
    public var retryDelay: TimeInterval

    public init(timeout: TimeInterval = 60, retries: Int = 2, retryDelay: TimeInterval = 0.6) {
        self.timeout = timeout
        self.retries = retries
        self.retryDelay = retryDelay
    }
}

public enum LLMStreamingError: Error, LocalizedError, Sendable {
    case missingAPIURL(label: String)
    case invalidURL(String)
    case invalidAPIKey(label: String, reason: String)
    case invalidConfiguration(String)
    case nonHTTPResponse
    case httpStatus(code: Int, body: String)
    case upstreamError(String)
    case malformedSSE(String)
    case connectionRetriesExhausted(label: String, attempts: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIURL(let label): return "[\(label)] 未配置 API URL"
        case .invalidURL(let value): return "Invalid LLM stream URL: \(value)"
        case .invalidAPIKey(let label, let reason): return "[\(label)] \(reason)"
        case .invalidConfiguration(let reason): return "Invalid LLM streaming configuration: \(reason)"
        case .nonHTTPResponse: return "LLM streaming response was not HTTP"
        case .httpStatus(let code, let body): return "LLM upstream returned HTTP \(code): \(body)"
        case .upstreamError(let reason): return "LLM stream upstream error: \(reason)"
        case .malformedSSE(let reason): return "Malformed LLM SSE response: \(reason)"
        case .connectionRetriesExhausted(let label, let attempts, let reason):
            return "LLM[\(label)] streaming failed after \(attempts) attempts: \(reason)"
        }
    }
}

/// Opens incremental OpenAI-compatible completion streams using the same URL normalization,
/// authentication, browser headers, and DeepSeek V4 handling as LLMTransport.
public struct LLMStreamingClient: Sendable {
    private let session: URLSession
    private let keyValidator: any LLMAPIKeyValidating

    public init(session: URLSession = .shared, keyValidator: any LLMAPIKeyValidating = PermissiveLLMAPIKeyValidator()) {
        self.session = session
        self.keyValidator = keyValidator
    }

    /// Connects to /chat/completions and returns an event stream without buffering the full response.
    ///
    /// The caller should consume the returned AsyncThrowingStream promptly. Cancelling the
    /// consuming task cancels the reader task and releases the URLSession response sequence.
    public func openCompletion(
        configuration: LLMTransportConfiguration,
        payload: [String: Any],
        label: String,
        options: LLMStreamOptions = LLMStreamOptions()
    ) async throws -> LLMCompletionStream {
        let endpointString = LLMTransport.normalizeChatURL(configuration.apiURL) ?? ""
        guard !endpointString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMStreamingError.missingAPIURL(label: label)
        }
        guard let endpoint = URL(string: endpointString),
              let scheme = endpoint.scheme?.lowercased(),
              ["http", "https"].contains(scheme), endpoint.host != nil,
              endpoint.user == nil, endpoint.password == nil else {
            throw LLMStreamingError.invalidURL(endpointString)
        }
        guard let problem = keyValidator.validationProblem(for: configuration.apiKey) else {
            // Continue below; validation is repeated as a positive guard to keep errors explicit.
            return try await connect(endpoint: endpoint, endpointString: endpointString, configuration: configuration, payload: payload, label: label, options: options)
        }
        throw LLMStreamingError.invalidAPIKey(label: label, reason: problem)
    }

    private func connect(
        endpoint: URL,
        endpointString: String,
        configuration: LLMTransportConfiguration,
        payload: [String: Any],
        label: String,
        options: LLMStreamOptions
    ) async throws -> LLMCompletionStream {
        guard options.timeout > 0, options.timeout.isFinite else {
            throw LLMStreamingError.invalidConfiguration("timeout must be finite and greater than zero")
        }
        guard options.retries >= 0 else {
            throw LLMStreamingError.invalidConfiguration("retries must not be negative")
        }
        guard options.retryDelay >= 0, options.retryDelay.isFinite else {
            throw LLMStreamingError.invalidConfiguration("retryDelay must be finite and non-negative")
        }

        var body = payload
        let model = (payload["model"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? configuration.model
        body["model"] = model
        if LLMTransport.isV4Model(model), body["thinking"] == nil {
            body["thinking"] = ["type": "disabled"]
        }
        // The proxy always asks for streaming, and requests usage in the terminal frame.
        body["stream"] = true
        var streamOptions = body["stream_options"] as? [String: Any] ?? [:]
        if streamOptions["include_usage"] == nil {
            streamOptions["include_usage"] = true
        }
        body["stream_options"] = streamOptions

        let encoded: Data
        do {
            encoded = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            throw LLMStreamingError.invalidConfiguration("Request body is not valid JSON: \(error.localizedDescription)")
        }

        var lastError = "unknown upstream failure"
        for attempt in 0...options.retries {
            try Task.checkCancellation()
            var request = URLRequest(url: endpoint, timeoutInterval: options.timeout)
            request.httpMethod = "POST"
            request.httpBody = encoded
            for (key, value) in LLMTransport.streamHeadersBase {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

            do {
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw LLMStreamingError.nonHTTPResponse
                }
                if (200..<300).contains(http.statusCode) {
                    let stream = makeEventStream(bytes: bytes)
                    return LLMCompletionStream(
                        endpoint: endpointString,
                        model: model,
                        statusCode: http.statusCode,
                        events: stream.events,
                        cancel: stream.cancel
                    )
                }

                let bodyText = await Self.readErrorPrefix(bytes, limit: 300)
                if http.statusCode < 500 {
                    throw LLMStreamingError.httpStatus(code: http.statusCode, body: bodyText)
                }
                lastError = "upstream HTTP \(http.statusCode)" + (bodyText.isEmpty ? "" : " | " + bodyText)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as LLMStreamingError {
                if case .httpStatus = error { throw error }
                if case .nonHTTPResponse = error { throw error }
                lastError = error.localizedDescription
            } catch {
                lastError = error.localizedDescription
            }

            if attempt < options.retries {
                let delay = options.retryDelay * Double(attempt + 1)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(min(delay, 300) * 1_000_000_000))
                }
            }
        }
        throw LLMStreamingError.connectionRetriesExhausted(
            label: label,
            attempts: options.retries + 1,
            reason: String(lastError.prefix(400))
        )
    }

    private static func readErrorPrefix(_ bytes: URLSession.AsyncBytes, limit: Int) async -> String {
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= limit { break }
            }
        } catch {
            // Preserve the HTTP status as the primary diagnostic if reading its body fails.
        }
        return String(decoding: data.prefix(limit), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func makeEventStream(bytes: URLSession.AsyncBytes) -> (events: AsyncThrowingStream<LLMStreamEvent, Error>, cancel: @Sendable () -> Void) {
        let taskBox = LLMStreamTaskBox()
        let stream = AsyncThrowingStream<LLMStreamEvent, Error> { continuation in
            let task = Task {
                do {
                    var parser = LLMServerSentEventsParser()
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        for event in try parser.append(line: line) {
                            switch event {
                            case .done:
                                continuation.yield(.completed(finishReason: nil))
                                continuation.finish()
                                return
                            case .data(let data, let eventName):
                                let normalized = try Self.decode(data: data, eventName: eventName)
                                // A finish_reason chunk may be followed by a usage-only
                                // chunk; keep reading until [DONE] or the HTTP body ends.
                                for item in normalized {
                                    continuation.yield(item)
                                }
                            }
                        }
                    }
                    for event in try parser.finish() {
                        if case .data(let data, let eventName) = event {
                            for item in try Self.decode(data: data, eventName: eventName) { continuation.yield(item) }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            taskBox.set(task)
            continuation.onTermination = { @Sendable _ in taskBox.cancel() }
        }
        return (stream, { taskBox.cancel() })
    }

    private static func decode(data: String, eventName: String = "") throws -> [LLMStreamEvent] {
        guard data != "[DONE]" else { return [.completed(finishReason: nil)] }
        guard let bytes = data.data(using: .utf8) else {
            throw LLMStreamingError.malformedSSE("SSE data could not be encoded as UTF-8")
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
        } catch {
            throw LLMStreamingError.malformedSSE("event data is not valid JSON: \(error.localizedDescription)")
        }
        guard let payload = object as? [String: Any] else {
            return eventName.isEmpty ? [.raw(data: data)] : [.providerEvent(name: eventName, data: data)]
        }
        if let errorObject = payload["error"] as? [String: Any] {
            let message = (errorObject["message"] as? String) ?? (errorObject["type"] as? String) ?? data
            throw LLMStreamingError.upstreamError(message)
        }

        var events: [LLMStreamEvent] = []
        if let usage = payload["usage"] as? [String: Any] {
            events.append(.usage(LLMStreamUsage(
                promptTokens: integer(usage["prompt_tokens"]),
                completionTokens: integer(usage["completion_tokens"]),
                promptCacheHitTokens: optionalInteger(usage["prompt_cache_hit_tokens"]),
                promptCacheMissTokens: optionalInteger(usage["prompt_cache_miss_tokens"])
            )))
        }
        if let choices = payload["choices"] as? [[String: Any]] {
            for (choiceIndex, choice) in choices.enumerated() {
                if let delta = choice["delta"] as? [String: Any] {
                    if let content = delta["content"] as? String, !content.isEmpty {
                        events.append(.contentDelta(content))
                    }
                    if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                        events.append(.reasoningDelta(reasoning))
                    }
                    if let refusal = delta["refusal"] as? String, !refusal.isEmpty {
                        events.append(.refusalDelta(refusal))
                    }
                    if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                        for toolCall in toolCalls {
                            let index = integer(toolCall["index"])
                            let function = toolCall["function"] as? [String: Any]
                            events.append(.toolCallDelta(
                                choiceIndex: choiceIndex,
                                index: index,
                                id: toolCall["id"] as? String,
                                type: toolCall["type"] as? String,
                                functionName: function?["name"] as? String,
                                arguments: function?["arguments"] as? String
                            ))
                        }
                    }
                }
                if let finish = choice["finish_reason"], !(finish is NSNull) {
                    events.append(.completed(finishReason: finish as? String))
                }
            }
        }
        if events.isEmpty {
            if !eventName.isEmpty {
                events.append(.providerEvent(name: eventName, data: data))
            } else {
                events.append(.raw(data: data))
            }
        }
        return events
    }

    private static func integer(_ value: Any?) -> Int {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return 0
    }

    private static func optionalInteger(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return nil
    }
}

public struct LLMCompletionStream: Sendable {
    public let endpoint: String
    public let model: String
    public let statusCode: Int
    public let events: AsyncThrowingStream<LLMStreamEvent, Error>
    private let cancelReader: @Sendable () -> Void

    fileprivate init(endpoint: String, model: String, statusCode: Int, events: AsyncThrowingStream<LLMStreamEvent, Error>, cancel: @escaping @Sendable () -> Void) {
        self.endpoint = endpoint
        self.model = model
        self.statusCode = statusCode
        self.events = events
        self.cancelReader = cancel
    }

    /// Explicitly stops reading and releases the underlying URLSession byte sequence.
    public func cancel() {
        cancelReader()
    }
}

private final class LLMStreamTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func set(_ task: Task<Void, Never>) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}

/// Minimal incremental SSE line/event framing parser. URLSession.AsyncBytes.lines handles
/// arbitrary UTF-8/network chunk boundaries; this parser handles SSE event/data semantics.
private struct LLMServerSentEventsParser {
    enum Parsed {
        case data(String, eventName: String)
        case done
    }

    private var dataLines: [String] = []
    private var eventName = ""

    mutating func append(line: String) throws -> [Parsed] {
        if line.isEmpty { return dispatch() }
        if line.hasPrefix(":") { return [] } // comment / heartbeat
        let field: String
        let value: String
        if let colon = line.firstIndex(of: ":") {
            field = String(line[..<colon])
            var rest = String(line[line.index(after: colon)...])
            if rest.first == " " { rest.removeFirst() }
            value = rest
        } else {
            field = line
            value = ""
        }
        switch field {
        case "data": dataLines.append(value)
        case "event": eventName = value
        default: break
        }
        return []
    }

    mutating func finish() throws -> [Parsed] {
        dispatch()
    }

    private mutating func dispatch() -> [Parsed] {
        defer {
            dataLines.removeAll(keepingCapacity: true)
            eventName = ""
        }
        guard !dataLines.isEmpty else { return [] }
        let data = dataLines.joined(separator: "\n")
        if data == "[DONE]" { return [.done] }
        return [.data(data, eventName: eventName)]
    }
}
