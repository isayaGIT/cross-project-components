import Foundation

/// Structured result compatible with the source service's sendVoice/confidence/reason/meta shape.
public struct VoiceDecisionResult: Codable, Sendable, Equatable {
    public let sendVoice: Bool
    public let confidence: Double
    public let reason: String
    public let meta: VoiceDecisionMetadata?

    public init(
        sendVoice: Bool,
        confidence: Double,
        reason: String,
        meta: VoiceDecisionMetadata? = nil
    ) {
        self.sendVoice = sendVoice
        self.confidence = confidence
        self.reason = reason
        self.meta = meta
    }

    private enum CodingKeys: String, CodingKey {
        case sendVoice
        case confidence
        case reason
        case meta
    }
}

/// Metadata emitted by the orchestration layer.
/// A fast-path result has `fastPath == true`; a model-path result has `false`.
/// Error metadata includes the bounded diagnostic string when available.
public struct VoiceDecisionMetadata: Codable, Sendable, Equatable {
    public let fastPath: Bool?
    public let error: String?

    public init(fastPath: Bool? = nil, error: String? = nil) {
        self.fastPath = fastPath
        self.error = error
    }

    public static let fastPathMetadata = VoiceDecisionMetadata(fastPath: true)
    public static let modelPathMetadata = VoiceDecisionMetadata(fastPath: false)
}

/// Policy limits inherited from should_send_voice.py.
public struct VoiceDecisionConfiguration: Sendable, Equatable {
    public let maxCharacters: Int
    public let recentDialogLimit: Int
    public let reasonLimit: Int
    public let errorLimit: Int
    public let minimumVoiceConfidence: Double

    public init(
        maxCharacters: Int = 40,
        recentDialogLimit: Int = 1200,
        reasonLimit: Int = 80,
        errorLimit: Int = 200,
        minimumVoiceConfidence: Double = 0.55
    ) {
        self.maxCharacters = max(0, maxCharacters)
        self.recentDialogLimit = max(0, recentDialogLimit)
        self.reasonLimit = max(0, reasonLimit)
        self.errorLimit = max(0, errorLimit)
        self.minimumVoiceConfidence = min(1.0, max(0.0, minimumVoiceConfidence))
    }
}

public enum AutomaticVoiceDecisionError: Error, Sendable, Equatable {
    /// The decoded JSON value was valid JSON, but was not a JSON object.
    case expectedJSONObject
}
