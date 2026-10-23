import Foundation

/// Source-compatible closures for the existing gateway API.
/// Bind these closures to LLMGateway methods in the host integration layer; this module
/// intentionally does not duplicate request execution, transport, or Anthropic handling.
public struct LLMProviderCompatibility: Sendable {
    public typealias Chat = @Sendable (_ taskKey: String, _ messages: Any) async throws -> Any
    public typealias CallWithConfiguration = @Sendable (_ configuration: LLMRouting.ResolvedConfiguration, _ label: String, _ messages: Any) async throws -> Any
    public typealias NormalizeChatURL = @Sendable (_ apiURL: String?) -> String?
    public typealias ExtractContent = @Sendable (_ response: [String: Any]) throws -> String
    public typealias IsV4Model = @Sendable (_ model: String?) -> Bool

    public let chat: Chat
    public let callWithConfiguration: CallWithConfiguration
    public let normalizeChatURL: NormalizeChatURL
    public let extractContent: ExtractContent
    public let isV4Model: IsV4Model
    public let browserUserAgent: String

    public init(chat: @escaping Chat, callWithConfiguration: @escaping CallWithConfiguration, normalizeChatURL: @escaping NormalizeChatURL, extractContent: @escaping ExtractContent, isV4Model: @escaping IsV4Model, browserUserAgent: String) {
        self.chat = chat; self.callWithConfiguration = callWithConfiguration
        self.normalizeChatURL = normalizeChatURL; self.extractContent = extractContent
        self.isV4Model = isV4Model; self.browserUserAgent = browserUserAgent
    }
}

/// Cohesive façade for routing, cost accounting, telemetry, and optional provider aliases.
public final class LLMRoutingFacade: @unchecked Sendable {
    public let router: LLMRouting
    public let telemetry: LLMUsageTelemetry
    private let compatibility: LLMProviderCompatibility?

    public init(router: LLMRouting, telemetry: LLMUsageTelemetry, compatibility: LLMProviderCompatibility? = nil) {
        self.router = router; self.telemetry = telemetry; self.compatibility = compatibility
    }

    public func resolve(_ taskKey: String) -> LLMRouting.ResolvedConfiguration { router.resolve(taskKey) }
    public func keyProblem(_ apiKey: String?) -> String { router.keyProblem(apiKey) }
    public func estimateCost(model: String?, promptTokens: Any?, completionTokens: Any?) -> Double {
        LLMCostAccounting.estimateCost(model: model, promptTokens: promptTokens, completionTokens: completionTokens)
    }
    public func record(_ record: LLMUsageTelemetry.Record) async { await telemetry.record(record) }
    public func usage() async -> [String: Any] { await telemetry.getUsage() }

    public func chat(taskKey: String, messages: Any) async throws -> Any {
        guard let compatibility else { throw FacadeError.gatewayCompatibilityNotConfigured }
        return try await compatibility.chat(taskKey, messages)
    }

    public func callWithConfiguration(_ configuration: LLMRouting.ResolvedConfiguration, label: String, messages: Any) async throws -> Any {
        guard let compatibility else { throw FacadeError.gatewayCompatibilityNotConfigured }
        return try await compatibility.callWithConfiguration(configuration, label, messages)
    }

    public func normalizeChatURL(_ apiURL: String?) -> String? { compatibility?.normalizeChatURL(apiURL) }
    public func extractContent(from response: [String: Any]) throws -> String {
        guard let compatibility else { throw FacadeError.gatewayCompatibilityNotConfigured }
        return try compatibility.extractContent(response)
    }
    public func isV4Model(_ model: String?) -> Bool { compatibility?.isV4Model(model) ?? false }
    public var browserUserAgent: String { compatibility?.browserUserAgent ?? "" }

    public enum FacadeError: Error, LocalizedError {
        case gatewayCompatibilityNotConfigured
        public var errorDescription: String? { "Gateway/provider compatibility closures have not been configured." }
    }
}
