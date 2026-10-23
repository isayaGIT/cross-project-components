import Foundation

/// Stable route identifiers returned by the backend classifier.
public enum BehaviorRouteIntent: String, Codable, CaseIterable, Sendable {
    case enterNSFW = "enter_nsfw"
    case stay
    case exitNSFW = "exit_nsfw"
    case unclear
}

/// Stable cue labels used by the original classification prompt.
public enum BehaviorRouteCue: String, Codable, CaseIterable, Sendable {
    case explicit
    case innuendo
    case sarcasm
    case aftercare
    case daily
    case other
}

/// Runtime channel. The full pipeline maps every non-`nsfw` string to `daily`.
public enum BehaviorRouteMode: String, Codable, Sendable {
    case daily
    case nsfw

    public init(normalizing value: String?) {
        self = value == Self.nsfw.rawValue ? .nsfw : .daily
    }
}

/// Normalized result of parsing the LLM classifier response.
public struct ParsedBehaviorRoute: Equatable, Sendable {
    public let intent: BehaviorRouteIntent
    public let confidence: Double
    public let cue: BehaviorRouteCue

    public init(intent: BehaviorRouteIntent, confidence: Double, cue: BehaviorRouteCue) {
        self.intent = intent
        self.confidence = min(1, max(0, confidence))
        self.cue = cue
    }
}

/// Result of deterministic heuristic classification, before pipeline metadata is added.
public struct BehaviorRouteHeuristic: Equatable, Sendable {
    public let intent: BehaviorRouteIntent
    public let confidence: Double
    public let cue: BehaviorRouteCue

    public init(intent: BehaviorRouteIntent, confidence: Double, cue: BehaviorRouteCue) {
        self.intent = intent
        self.confidence = confidence
        self.cue = cue
    }
}

/// Result corresponding to the Python `run_behavior_route` return dictionary.
public struct BehaviorRouteResult: Codable, Equatable, Sendable {
    public struct Metadata: Codable, Equatable, Sendable {
        public var fastPath: Bool?
        public var currentMode: String
        public var error: String?

        public init(fastPath: Bool? = nil, currentMode: BehaviorRouteMode, error: String? = nil) {
            self.fastPath = fastPath
            self.currentMode = currentMode.rawValue
            self.error = error
        }

        enum CodingKeys: String, CodingKey {
            case fastPath
            case currentMode
            case error
        }
    }

    public var intent: BehaviorRouteIntent
    public var confidence: Double
    public var cue: BehaviorRouteCue
    public var meta: Metadata

    public init(intent: BehaviorRouteIntent, confidence: Double, cue: BehaviorRouteCue, meta: Metadata) {
        self.intent = intent
        self.confidence = Self.clampConfidence(confidence)
        self.cue = cue
        self.meta = meta
    }

    /// Returns the original dictionary-shaped contract with camel-case metadata keys.
    public func jsonObject() -> [String: Any] {
        var metadata: [String: Any] = ["currentMode": meta.currentMode]
        if let fastPath = meta.fastPath { metadata["fastPath"] = fastPath }
        if let error = meta.error { metadata["error"] = error }
        return [
            "intent": intent.rawValue,
            "confidence": confidence,
            "cue": cue.rawValue,
            "meta": metadata
        ]
    }

    private static func clampConfidence(_ value: Double) -> Double {
        // Python's max(0.0, min(1.0, nan)) evaluates to 1.0 with this operand order.
        min(1, max(0, value))
    }
}
