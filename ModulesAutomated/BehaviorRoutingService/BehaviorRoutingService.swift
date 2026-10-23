import Foundation

/// Backend-only port of `cloud/services/behavior_route.py`.
///
/// Classifies channel transitions. It does not generate replies, persist channel
/// state, or implement frontend sticky-exit behavior.
public struct BehaviorRoutingService: Sendable {
    public typealias LLMJSONCall = @Sendable (_ prompt: String) async throws -> String

    public static let systemPrompt = """你是「行为频道分类器」，服务于恋爱陪伴私聊。
判断用户本轮话语相对「日常频道 / NSFW 亲密频道」的意图。

只输出 JSON（不要 markdown）：
{
  "intent": "enter_nsfw" | "stay" | "exit_nsfw" | "unclear",
  "confidence": 0.0到1.0,
  "cue": "explicit" | "innuendo" | "sarcasm" | "aftercare" | "daily" | "other"
}

规则（务必遵守）：
1. enter_nsfw：用户想进入或继续成人/亲密动作内容。含直接请求、隐晦暗示、反话暗示（嘴上说不要其实在撩）、角色扮演邀请。进门槛要灵敏，宁可 enter 也不要漏。
2. stay：当前若已在亲密语境，用户仍在延续亲密/余韵/调情；或本轮与频道切换无关的短应答（嗯、好、哈哈）且上下文仍偏亲密。
3. exit_nsfw：用户明确结束亲密话题，或开始讲完全日常、与成人内容无关的新话题（吃饭、工作、出门、吐槽日常等）。aftercare（抱抱、累了、亲亲安抚）不算 exit，应 stay + cue=aftercare。
4. unclear：无法判断时用这个，系统会保持原频道。
5. cue=sarcasm / innuendo 时，若语义指向亲密，intent 用 enter_nsfw（或 stay）。
6. confidence：明确指令 ≥0.9；暗示 0.55～0.85；纯猜测 <0.5 则改 unclear。
"""

    private static let hardExitPattern = #"(不聊这个了|别聊这个了|结束了吧|结束吧|切回日常|回到日常|关掉\s*nsfw|停止色情|换个话题|聊点别的|不想做了|做完了|完事了|到此为止|收一收|冷静一下|不要继续了|别继续了)"#
    private static let hardEnterPattern = #"(开启\s*nsfw|切换到\s*nsfw|进入\s*nsfw|想色色|想涩涩|做爱好吗|想要你|想和你做|继续做|再来一次|来做吧)"#
    private static let acknowledgementPattern = #"^(嗯+|哦+|啊+|哈+|好+|行+|ok|OK|好的|嗯嗯|哈哈+|嘻嘻+|继续|还要|抱|抱抱|亲亲|么么|爱你|想你)[\s!！。~～…]*$"#
    private static let aftercarePattern = #"(抱|亲|爱|想你)"#
    private static let dailyShortMessageExclusionPattern = #"[色涩想要抱亲做]"#
    private static let embeddedJSONObjectPattern = #"\{[\s\S]*\}"#
    private static let jsonFencePattern = #"```json\s*"#
    private static let genericFencePattern = #"```\s*"#

    public init() {}

    /// Returns a deterministic classification if one of the source fast paths applies.
    /// This standalone method intentionally uses exact mode-string comparisons.
    public func heuristicIntent(userMessage: String?, currentMode: String = "daily") -> BehaviorRouteHeuristic? {
        let message = (userMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            return BehaviorRouteHeuristic(intent: .unclear, confidence: 1.0, cue: .other)
        }
        if Self.matches(Self.hardExitPattern, in: message) {
            return BehaviorRouteHeuristic(intent: .exitNSFW, confidence: 0.98, cue: .explicit)
        }
        if Self.matches(Self.hardEnterPattern, in: message) {
            return BehaviorRouteHeuristic(intent: .enterNSFW, confidence: 0.95, cue: .explicit)
        }
        if currentMode == "nsfw", Self.matches(Self.acknowledgementPattern, in: message) {
            let cue: BehaviorRouteCue = Self.matches(Self.aftercarePattern, in: message) ? .aftercare : .other
            return BehaviorRouteHeuristic(intent: .stay, confidence: 0.8, cue: cue)
        }
        if currentMode == "daily",
           message.unicodeScalars.count <= 2,
           !Self.matches(Self.dailyShortMessageExclusionPattern, in: message) {
            return BehaviorRouteHeuristic(intent: .unclear, confidence: 0.7, cue: .daily)
        }
        return nil
    }

    /// Builds the user prompt using the source's Chinese text and ordering.
    public func buildUserPrompt(userMessage: String?, recentDialog: String = "", currentMode: String = "daily") -> String {
        let mode = currentMode == "nsfw" ? BehaviorRouteMode.nsfw : .daily
        var parts = ["【当前频道】" + (mode == .nsfw ? "NSFW 亲密" : "日常")]
        if !recentDialog.isEmpty {
            let suffix = String(recentDialog.unicodeScalars.suffix(1800))
            parts.append("\n【最近对话】\n" + suffix)
        }
        parts.append("\n【她刚说】\n" + (userMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        parts.append("\n请分类本轮意图。")
        return parts.joined(separator: "\n")
    }

    /// Parses plain, fenced, or embedded JSON and normalizes its public fields.
    public func parseRouteJSON(_ content: String?) -> ParsedBehaviorRoute {
        guard let content, !content.isEmpty else {
            return ParsedBehaviorRoute(intent: .unclear, confidence: 0, cue: .other)
        }
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        text = Self.replacing(Self.jsonFencePattern, in: text, with: "")
        text = Self.replacing(Self.genericFencePattern, in: text, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var object = BehaviorRouteJSON.decodeObject(text)
        if object == nil,
           let range = text.range(of: Self.embeddedJSONObjectPattern, options: .regularExpression) {
            object = BehaviorRouteJSON.decodeObject(String(text[range]))
        }
        guard let data = object else {
            return ParsedBehaviorRoute(intent: .unclear, confidence: 0, cue: .other)
        }

        let rawIntent = BehaviorRouteJSON.pythonString(data["intent"], fallback: "unclear")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = BehaviorRouteIntent(rawValue: rawIntent) ?? .unclear
        let rawConfidence = BehaviorRouteJSON.pythonFloat(data["confidence"]) ?? 0
        let confidence = min(1, max(0, rawConfidence))
        let rawCue = BehaviorRouteJSON.pythonString(data["cue"], fallback: "other")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cue = BehaviorRouteCue(rawValue: rawCue) ?? .other
        return ParsedBehaviorRoute(intent: intent, confidence: confidence, cue: cue)
    }

    /// Runs the complete pipeline corresponding to Python `run_behavior_route`.
    /// LLM errors become an unclear result rather than escaping to the caller.
    public func run(
        llmJSONCall: LLMJSONCall,
        userMessage: String?,
        recentDialog: String = "",
        currentMode: String = "daily"
    ) async -> BehaviorRouteResult {
        let mode = BehaviorRouteMode(normalizing: currentMode)
        if let fast = heuristicIntent(userMessage: userMessage, currentMode: mode.rawValue) {
            return BehaviorRouteResult(
                intent: fast.intent,
                confidence: fast.confidence,
                cue: fast.cue,
                meta: .init(fastPath: true, currentMode: mode)
            )
        }

        let prompt = Self.systemPrompt + "\n\n" + buildUserPrompt(
            userMessage: userMessage,
            recentDialog: recentDialog,
            currentMode: mode.rawValue
        )
        do {
            let response = try await llmJSONCall(prompt)
            let parsed = parseRouteJSON(response)
            return BehaviorRouteResult(
                intent: parsed.intent,
                confidence: parsed.confidence,
                cue: parsed.cue,
                meta: .init(fastPath: false, currentMode: mode)
            )
        } catch {
            return BehaviorRouteResult(
                intent: .unclear,
                confidence: 0,
                cue: .other,
                meta: .init(
                    currentMode: mode,
                    error: String(error.localizedDescription.prefix(200))
                )
            )
        }
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
