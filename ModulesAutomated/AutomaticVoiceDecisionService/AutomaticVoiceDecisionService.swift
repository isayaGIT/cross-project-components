import Foundation
import CoreFoundation

/// Decides whether a newly generated assistant reply should be delivered as voice only.
/// The injected model closure is expected to return the model's textual JSON response.
public struct AutomaticVoiceDecisionService: Sendable {
    public typealias LLMJSONCall = @Sendable (_ prompt: String) async throws -> String

    public let configuration: VoiceDecisionConfiguration

    public init(configuration: VoiceDecisionConfiguration = VoiceDecisionConfiguration()) {
        self.configuration = configuration
    }

    /// Original conservative decision prompt. Keep aligned with should_send_voice.py.
    public static let systemPrompt = """你是「微信式语音气泡」决策器，服务于恋爱陪伴私聊。
给定助手刚生成的一条短回复，判断它是否更适合「只发语音、不显示文字气泡」。

只输出 JSON（不要 markdown）：
{
  "sendVoice": true | false,
  "confidence": 0.0到1.0,
  "reason": "极短中文原因"
}

规则（务必遵守）：
1. 默认 false。只有「发语音比打字更自然」才 true。宁可漏，勿滥。
2. true 典型：极短口语应答或亲密短句，如 嗯/好呀/晚安/在呀/想你了/哈哈/抱抱/么么/来了/稍等。
3. false：超过约一句的信息、解释、提问串、计划安排、带链接/列表、多行、需要以后回看的文字、舞台指示/括号旁白为主。
4. 即使很短，若是明确信息确认（时间地点数字安排）也倾向 false。
5. confidence：非常明确 ≥0.85；犹豫则 false 且 confidence<0.6。
"""

    /// Returns a fast-path rejection, or nil when a model decision is needed.
    public func hardReject(
        _ assistantText: String?,
        partsCount: Int = 1
    ) -> VoiceDecisionResult? {
        let text = Self.trim(assistantText ?? "")

        if text.isEmpty {
            return Self.fastRejection(reason: "empty")
        }
        if partsCount > 1 || text.contains("\n") {
            return Self.fastRejection(reason: "multiline")
        }
        if Self.matches(#"https?://"#, in: text, options: [.caseInsensitive]) {
            return Self.fastRejection(reason: "url")
        }
        if text.contains("```") {
            return Self.fastRejection(reason: "code")
        }

        // Remove parenthesized stage directions before evaluating length.
        let withoutStageDirections = Self.replacingMatches(
            pattern: #"[（(][^)）]*[)）]"#,
            in: text,
            with: ""
        )
        let content = Self.trim(withoutStageDirections)
        if content.isEmpty {
            return Self.fastRejection(reason: "stage-only")
        }
        if content.unicodeScalars.count > configuration.maxCharacters {
            return Self.fastRejection(reason: "too-long")
        }
        return nil
    }

    /// Builds the user portion of the prompt. Recent context is truncated by Unicode scalar,
    /// matching Python string slicing more closely than Swift Character counting.
    public func buildUserPrompt(
        assistantText: String?,
        recentDialog: String? = nil
    ) -> String {
        var parts: [String] = []

        if let recentDialog, !recentDialog.isEmpty {
            parts.append("【最近对话】\n" + Self.suffixScalars(recentDialog, limit: configuration.recentDialogLimit))
        }

        parts.append("【助手刚要发出的文字】\n" + Self.trim(assistantText ?? ""))
        parts.append("请判断是否改为只发语音。")
        return parts.joined(separator: "\n\n")
    }

    /// Parses the model response without adding orchestration metadata.
    /// Malformed JSON returns `parse-fail`. A valid non-object JSON value throws,
    /// matching the source Python implementation's failure when it calls `.get` on it.
    public func parseDecisionJSON(_ content: String?) throws -> VoiceDecisionResult {
        guard let content, !content.isEmpty else {
            return VoiceDecisionResult(sendVoice: false, confidence: 0.0, reason: "empty-llm")
        }

        var candidate = content.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate = Self.replacingMatches(pattern: #"```json\s*"#, in: candidate, with: "")
        candidate = Self.replacingMatches(pattern: #"```\s*"#, in: candidate, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Only decoding errors trigger the embedded-object fallback. A successfully decoded
        // scalar or array is not treated as malformed JSON; it must surface as a type error.
        let decodedValue: Any
        do {
            decodedValue = try Self.decodeJSONValue(candidate)
        } catch {
            guard let embedded = Self.firstGreedyJSONObject(in: candidate) else {
                return VoiceDecisionResult(sendVoice: false, confidence: 0.0, reason: "parse-fail")
            }
            do {
                decodedValue = try Self.decodeJSONValue(embedded)
            } catch {
                return VoiceDecisionResult(sendVoice: false, confidence: 0.0, reason: "parse-fail")
            }
        }

        guard let data = decodedValue as? [String: Any] else {
            throw AutomaticVoiceDecisionError.expectedJSONObject
        }

        let sendVoice: Bool
        if let value = data["sendVoice"] as? String {
            let normalized = Self.trim(value).lowercased()
            sendVoice = ["1", "true", "yes", "y"].contains(normalized)
        } else {
            sendVoice = Self.pythonTruthy(data["sendVoice"])
        }

        var confidence = Self.pythonFloat(data["confidence"]) ?? 0.0
        // Python's max(0.0, min(1.0, NaN)) evaluates to 1.0 due to comparison order.
        if confidence.isNaN {
            confidence = 1.0
        } else {
            confidence = max(0.0, min(1.0, confidence))
        }

        let rawReason = data["reason"]
        let reasonValue = Self.pythonTruthy(rawReason) ? Self.pythonString(rawReason!) : ""
        let trimmedReason = Self.trim(reasonValue)
        var reason = Self.prefixScalars(trimmedReason, limit: configuration.reasonLimit)
        if reason.isEmpty {
            reason = sendVoice ? "voice" : "text"
        }

        var finalSendVoice = sendVoice
        if finalSendVoice && confidence < configuration.minimumVoiceConfidence {
            finalSendVoice = false
            reason = "low-confidence"
        }

        return VoiceDecisionResult(
            sendVoice: finalSendVoice,
            confidence: confidence,
            reason: reason
        )
    }

    /// Full decision path. Errors fail closed and never request voice delivery.
    public func runAutoVoiceDecide(
        assistantText: String?,
        recentDialog: String? = nil,
        partsCount: Int = 1,
        llmJSONCall: LLMJSONCall
    ) async -> VoiceDecisionResult {
        if let fastResult = hardReject(assistantText, partsCount: partsCount) {
            return fastResult
        }

        let prompt = Self.systemPrompt + "\n\n" + buildUserPrompt(
            assistantText: assistantText,
            recentDialog: recentDialog ?? ""
        )

        do {
            let raw = try await llmJSONCall(prompt)
            let parsed = try parseDecisionJSON(raw)
            return VoiceDecisionResult(
                sendVoice: parsed.sendVoice,
                confidence: parsed.confidence,
                reason: parsed.reason,
                meta: .modelPathMetadata
            )
        } catch {
            return VoiceDecisionResult(
                sendVoice: false,
                confidence: 0.0,
                reason: "llm-error",
                meta: VoiceDecisionMetadata(
                    error: Self.prefixScalars(error.localizedDescription, limit: configuration.errorLimit)
                )
            )
        }
    }

    private static func fastRejection(reason: String) -> VoiceDecisionResult {
        VoiceDecisionResult(
            sendVoice: false,
            confidence: 1.0,
            reason: reason,
            meta: .fastPathMetadata
        )
    }

    private static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suffixScalars(_ value: String, limit: Int) -> String {
        guard limit > 0 else { return "" }
        return String(value.unicodeScalars.suffix(limit))
    }

    private static func prefixScalars(_ value: String, limit: Int) -> String {
        guard limit > 0 else { return "" }
        return String(value.unicodeScalars.prefix(limit))
    }

    private static func matches(
        _ pattern: String,
        in value: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    private static func replacingMatches(
        pattern: String,
        in value: String,
        with replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: replacement
        )
    }

    private static func firstGreedyJSONObject(in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\{[\s\S]*\}"#) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let swiftRange = Range(match.range, in: value) else {
            return nil
        }
        return String(value[swiftRange])
    }

    private static func decodeJSONValue(_ text: String) throws -> Any {
        try JSONSerialization.jsonObject(
            with: Data(text.utf8),
            options: [.fragmentsAllowed]
        )
    }

    private static func pythonTruthy(_ value: Any?) -> Bool {
        guard let value else { return false }
        if value is NSNull { return false }
        if let string = value as? String { return !string.isEmpty }
        if let number = value as? NSNumber { return number.doubleValue != 0.0 }
        if let array = value as? [Any] { return !array.isEmpty }
        if let object = value as? [String: Any] { return !object.isEmpty }
        return true
    }

    private static func pythonFloat(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if value is NSNull { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            return Double(trim(string))
        }
        return nil
    }

    /// Best-effort conversion for JSON values used as a Python `str(...)` equivalent.
    /// String reasons, the expected common case, are preserved exactly.
    private static func pythonString(_ value: Any) -> String {
        if value is NSNull { return "None" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : "False"
            }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + array.map { pythonRepr($0) }.joined(separator: ", ") + "]"
        }
        if let object = value as? [String: Any] {
            let pairs = object.map { key, value in
                "'" + key + "': " + pythonRepr(value)
            }
            return "{" + pairs.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }

    private static func pythonRepr(_ value: Any) -> String {
        if value is NSNull { return "None" }
        if let string = value as? String {
            let escaped = string.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "'" + escaped + "'"
        }
        return pythonString(value)
    }
}
