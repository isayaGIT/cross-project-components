import Foundation

public struct CompanionEnricher: Sendable {
    public typealias LLMCall = @Sendable (String) async throws -> String
    public let searchService: WebSearchService

    public init(searchService: WebSearchService) { self.searchService = searchService }

    private func matches(_ pattern: String, _ text: String) -> Bool {
        (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]).firstMatch(in: text, range: NSRange(text.startIndex..., in: text))) != nil
    }

    public func heuristicSkipSearch(_ message: String?) -> Bool {
        let text = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        if text.count <= 4 && !matches(#"小红书|种草|探店|哪里好玩|吃什么|攻略|推荐|安利|新闻|天气|气温|下雨|发布|上市|版本|百科|[?？].*(什么|怎么|为什么|哪里|谁|多少|是不是|有没有)|(什么|怎么|为什么|哪里|谁|多少).*[?？]"#, text) { return true }
        return matches(#"^(嗯+|哦+|啊+|哈+|好+|行+|ok|好的|知道了|没事|算了|晚安|早安|在吗|在干嘛|想你|抱抱|亲亲|爱你|么么|哈哈+|嘻嘻+|嗯嗯+)[\s!！。~～…]*$"#, text)
    }

    public func heuristicFastIntent(_ message: String) -> SearchIntent? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !heuristicSkipSearch(text) else { return nil }
        let fastPattern = #"小红书|种草|探店|哪里好玩|吃什么|攻略|推荐|安利|新闻|天气|气温|下雨|发布|上市|版本|百科|[?？].*(什么|怎么|为什么|哪里|谁|多少|是不是|有没有)|(什么|怎么|为什么|哪里|谁|多少).*[?？]"#
        let topicPattern = #"《[^》]{2,}》|[A-Za-z][A-Za-z0-9._\-]{2,}|新出的|刚出的|听说|最近很火|很火的"#
        guard matches(fastPattern, text) || matches(topicPattern, text) || text.count >= 24 else { return nil }
        var query = text.replacingOccurrences(of: #"[?？!！。~～…]+$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        query = query.replacingOccurrences(of: #"^(你知道|帮我查|搜一下|查查|查询)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if query.count > 24 { query = String(query.prefix(24)) }
        let bias = searchService.inferSearchBias(query)
        var hint = bias.xiaohongshu > bias.web ? "xiaohongshu" : "auto"
        if matches(#"新闻|天气|百科|发布|上市"#, text) { hint = "web" }
        return SearchIntent(shouldSearch: true, queries: [query], curiosity: "想更懂她刚说的这件事", sourceHints: [hint], fastPath: true)
    }

    public func buildIntentPrompt(userMessage: String, recentDialog: String?, memoryHints: String?, isPrivate: Bool) -> String {
        var parts = [isPrivate ? "【场景】方莓与张平的实时私聊（微信式）" : "【场景】剧情对话"]
        if let recentDialog, !recentDialog.isEmpty { parts.append("\n【最近对话】\n" + String(recentDialog.suffix(2000))) }
        if let memoryHints, !memoryHints.isEmpty { parts.append("\n【已知的关于她的片段】\n" + String(memoryHints.prefix(1200))) }
        parts.append("\n【她刚说】\n" + userMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        parts.append("\n请判断张平是否会悄悄上网查一下以便更懂她。")
        return parts.joined(separator: "\n")
    }

    public func parseIntentJSON(_ content: String?) -> SearchIntent {
        guard var text = content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return SearchIntent(shouldSearch: false) }
        text = text.replacingOccurrences(of: #"```json\s*"#, with: "", options: .regularExpression).replacingOccurrences(of: #"```\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        var object: [String: Any]?
        if let data = text.data(using: .utf8) { object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] }
        if object == nil, let range = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            object = try? JSONSerialization.jsonObject(with: Data(text[range].utf8)) as? [String: Any]
        }
        guard let data = object else { return SearchIntent(shouldSearch: false) }
        var queries: [String]
        if let array = data["queries"] as? [Any] { queries = array.map { stringValue($0) }.filter { !$0.isEmpty } }
        else if let value = data["queries"] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { queries = [value.trimmingCharacters(in: .whitespacesAndNewlines)] }
        else { queries = [] }
        queries = Array(queries.prefix(2))
        let rawHints = data["sourceHints"] ?? data["sourceHint"]
        var hints = (rawHints as? [Any])?.map { stringValue($0).lowercased() }.filter { !$0.isEmpty } ?? []
        if let single = rawHints as? String, !single.isEmpty { hints = [single.lowercased()] }
        while hints.count < queries.count { hints.append("auto") }
        return SearchIntent(shouldSearch: ((data["shouldSearch"] as? Bool) ?? false) && !queries.isEmpty, queries: queries, curiosity: stringValue(data["curiosity"]), sourceHints: Array(hints.prefix(queries.count)))
    }

    private func resolveMode(_ hint: String) -> String {
        switch hint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "xiaohongshu", "xhs", "小红书": return "xiaohongshu"
        case "web", "百科", "新闻": return "web"
        case "both": return "both"
        default: return "auto"
        }
    }

    public func runSearches(queries: [String], sourceHints: [String] = [], maxResults: Int = 4) async -> [SearchPayload] {
        var payloads: [SearchPayload] = []
        for (index, query) in queries.enumerated() {
            let mode = resolveMode(index < sourceHints.count ? sourceHints[index] : "auto")
            let results = await searchService.search(query, maxResults: maxResults, mode: mode)
            let source: String
            if !results.isEmpty && results.allSatisfy({ $0.source == "xiaohongshu" }) { source = "xiaohongshu" }
            else if results.contains(where: { $0.source == "xiaohongshu" }) { source = "mixed" }
            else { source = "web" }
            payloads.append(SearchPayload(query: query, summary: searchService.formatResultsForPrompt(query, results: results), rawSummary: "", resultCount: results.count, source: source, mode: mode))
        }
        return payloads
    }

    public func buildDigestPrompt(curiosity: String?, payloads: [SearchPayload]) -> String {
        var lines = ["动机：" + ((curiosity?.isEmpty == false) ? curiosity! : "想更懂她提到的这件事"), ""]
        for item in payloads {
            let label = item.source == "xiaohongshu" ? "小红书" : (item.source == "mixed" ? "混合" : "网页")
            lines.append("── 查「\(item.query)」（\(label)）──")
            lines.append(item.rawSummary.isEmpty ? item.summary : item.rawSummary)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    public func digestSearchResults(llmDigestCall: LLMCall?, curiosity: String?, payloads: [SearchPayload]) async -> String {
        guard let llmDigestCall, !payloads.isEmpty, payloads.contains(where: { $0.resultCount > 0 }) else { return "" }
        do {
            var text = try await llmDigestCall(buildDigestPrompt(curiosity: curiosity, payloads: payloads)).trimmingCharacters(in: .whitespacesAndNewlines)
            text = text.replacingOccurrences(of: #"```\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            return String(text.prefix(500))
        } catch { return "" }
    }

    public func formatContextBlock(curiosity: String?, payloads: [SearchPayload], digest: String = "") -> String {
        guard !payloads.isEmpty else { return "" }
        var lines = ["\n\n【张平刚刚偷偷查了一下 — 仅供你回应时参考】", "动机：" + ((curiosity?.isEmpty == false) ? curiosity! : "想更懂她提到的这件事"), "⚠️ 不要像播报新闻或搜索引擎一样列结果；不要刻意说「我搜了一下」；", "把信息融进恋人的关心、调侃或追问里，保持张平的语气和人格。", ""]
        if !digest.isEmpty { lines.append("【他脑子里琢磨的】"); lines.append(digest); lines.append("") }
        else {
            for item in payloads {
                let label = item.source == "xiaohongshu" ? "小红书" : (item.source == "mixed" ? "混合来源" : "网页")
                lines.append("── 查「\(item.query)」（\(label)）──")
                lines.append(item.summary)
                lines.append("")
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func run(userMessage: String, recentDialog: String? = nil, memoryHints: String = "", isPrivate: Bool = true, searchEnabled: Bool = true, llmJSONCall: LLMCall?, llmDigestCall: LLMCall? = nil) async -> EnrichmentResult {
        guard searchEnabled, !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EnrichmentResult(contextBlock: "", meta: EnrichmentMetadata(skipped: true))
        }
        if heuristicSkipSearch(userMessage) {
            return EnrichmentResult(contextBlock: "", meta: EnrichmentMetadata(skipped: true, reason: "heuristic_skip"))
        }
        var intent = heuristicFastIntent(userMessage)
        if intent == nil {
            guard let llmJSONCall else { return EnrichmentResult(contextBlock: "", meta: EnrichmentMetadata(error: "intent:LLM intent callback is unavailable")) }
            do { intent = parseIntentJSON(try await llmJSONCall(buildIntentPrompt(userMessage: userMessage, recentDialog: recentDialog, memoryHints: memoryHints, isPrivate: isPrivate))) }
            catch { return EnrichmentResult(contextBlock: "", meta: EnrichmentMetadata(error: "intent:" + error.localizedDescription)) }
        }
        guard let resolved = intent, resolved.shouldSearch else {
            return EnrichmentResult(contextBlock: "", meta: EnrichmentMetadata(searched: false, intent: intent))
        }
        let initial = await runSearches(queries: resolved.queries, sourceHints: resolved.sourceHints, maxResults: 4)
        let payloads = initial.map { SearchPayload(query: $0.query, summary: $0.summary, rawSummary: $0.summary, resultCount: $0.resultCount, source: $0.source, mode: $0.mode) }
        let digest = await digestSearchResults(llmDigestCall: llmDigestCall, curiosity: resolved.curiosity, payloads: payloads)
        let block = formatContextBlock(curiosity: resolved.curiosity, payloads: payloads, digest: digest)
        return EnrichmentResult(contextBlock: block, meta: EnrichmentMetadata(searched: true, queries: resolved.queries, curiosity: resolved.curiosity, resultCounts: payloads.map(\.resultCount), sources: payloads.map(\.source), fastPath: resolved.fastPath, digested: !digest.isEmpty))
    }
}
