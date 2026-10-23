import Foundation

public struct WebSearchService: Sendable {
    public let configuration: ResearchConfiguration
    public let transport: any ResearchHTTPTransport
    public let xiaohongshu: XiaohongshuClient

    public init(configuration: ResearchConfiguration = .environment(), transport: any ResearchHTTPTransport = URLSessionResearchTransport(), xiaohongshu: XiaohongshuClient? = nil) {
        self.configuration = configuration; self.transport = transport
        self.xiaohongshu = xiaohongshu ?? XiaohongshuClient(configuration: configuration, transport: transport)
    }

    private static let xhsPattern = #"小红书|种草|探店|穿搭|美妆|护肤|口红|咖啡|餐厅|美食|旅游|旅行|民宿|攻略|好物|安利|vlog|打卡|拍照|相机|健身餐|减脂餐|下午茶|甜品|火锅|酒吧|展览|市集|露营|徒步|温泉|酒店|机票|签证|平价|测评|推荐|哪里好玩|去哪玩|吃什么|怎么拍"#
    private static let webPattern = #"新闻|天气|气温|降雨|股价|汇率|发布|上市|版本|官宣|百科|维基|官网|下载|更新日志|changelog|API|github|stackoverflow|什么时候|几点|今年|昨天|今天|最近发生|地震|台风|谁赢了|比分|冠军|选举|政策|法规|疫情|[?？].*(什么|怎么|为什么|何时|哪里|多少|是否)"#
    private static let entityPattern = #"《[^》]{2,}》|[A-Za-z][A-Za-z0-9._\-]{2,}|乐队|专辑|单曲|电影|剧集|动漫|游戏|角色|cv|声优"#

    private func countMatches(_ pattern: String, _ text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    public func inferSearchBias(_ query: String) -> SearchBias {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SearchBias(xiaohongshu: 0, web: 0) }
        var xhs = countMatches(Self.xhsPattern, q), web = countMatches(Self.webPattern, q)
        if countMatches(Self.entityPattern, q) > 0 { web += 1 }
        if q.count <= 12 && web == 0 { xhs += 1 }
        return SearchBias(xiaohongshu: xhs, web: web)
    }

    public func resolveSearchModes(query: String, mode: String = "auto") -> [String] {
        switch mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "xiaohongshu": return ["xiaohongshu", "web"]
        case "web": return ["web", "xiaohongshu"]
        case "both": return ["xiaohongshu", "web"]
        default:
            guard xiaohongshu.isConfigured() else { return ["web"] }
            let bias = inferSearchBias(query)
            return bias.web > bias.xiaohongshu ? ["web", "xiaohongshu"] : ["xiaohongshu", "web"]
        }
    }

    private func get(_ url: URL, timeout: TimeInterval = 15, headers: [String: String] = [:]) async throws -> Data {
        let request = makeRequest(url: url, headers: ["User-Agent": configuration.userAgent].merging(headers) { _, new in new }, timeout: timeout)
        return try await transport.send(request, maximumBytes: configuration.maximumResponseBytes).data
    }

    private func serper(_ query: String, maxResults: Int) async throws -> [ResearchResult] {
        guard !configuration.serperAPIKey.isEmpty else { return [] }
        let url = URL(string: "https://google.serper.dev/search")!
        let body = try JSONSerialization.data(withJSONObject: ["q": query, "num": maxResults])
        let request = makeRequest(url: url, method: "POST", body: body, headers: ["User-Agent": configuration.userAgent, "X-API-KEY": configuration.serperAPIKey, "Content-Type": "application/json"], timeout: 20)
        let raw = try jsonObject(try await transport.send(request, maximumBytes: configuration.maximumResponseBytes).data)
        return (raw["organic"] as? [[String: Any]] ?? []).prefix(maxResults).map {
            ResearchResult(title: stringValue($0["title"]), snippet: stringValue($0["snippet"]), url: stringValue($0["link"]), source: "web")
        }
    }

    private func duckDuckGoInstant(_ query: String) async -> [ResearchResult] {
        do {
            var components = URLComponents(string: "https://api.duckduckgo.com/")!
            components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "no_html", value: "1"), URLQueryItem(name: "skip_disambig", value: "1")]
            let raw = try jsonObject(try await get(components.url!, timeout: 12))
            var results: [ResearchResult] = []
            let abstract = stringValue(raw["AbstractText"])
            if !abstract.isEmpty { results.append(ResearchResult(title: stringValue(raw["Heading"]).isEmpty ? query : stringValue(raw["Heading"]), snippet: abstract, url: stringValue(raw["AbstractURL"]))) }
            for topic in (raw["RelatedTopics"] as? [[String: Any]] ?? []).prefix(4) where !stringValue(topic["Text"]).isEmpty {
                results.append(ResearchResult(title: query, snippet: stringValue(topic["Text"]), url: stringValue(topic["FirstURL"])))
            }
            return results
        } catch { return [] }
    }

    private func duckDuckGoLite(_ query: String, maxResults: Int) async -> [ResearchResult] {
        do {
            let url = URL(string: "https://lite.duckduckgo.com/lite/")!
            let body = urlEncoded(["q": query]).data(using: .utf8)
            let request = makeRequest(url: url, method: "POST", body: body, headers: ["User-Agent": configuration.userAgent, "Content-Type": "application/x-www-form-urlencoded"], timeout: 18)
            let data = try await transport.send(request, maximumBytes: configuration.maximumResponseBytes).data
            let html = String(decoding: data, as: UTF8.self)
            let pattern = #"class="result-link"[^>]*>([^<]+)</a>.*?class="result-snippet"[^>]*>([^<]+)"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let range = NSRange(html.startIndex..., in: html)
            return regex.matches(in: html, range: range).prefix(maxResults).compactMap { match in
                guard let tr = Range(match.range(at: 1), in: html), let sr = Range(match.range(at: 2), in: html) else { return nil }
                let title = String(html[tr]).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = String(html[sr]).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty || !snippet.isEmpty else { return nil }
                return ResearchResult(title: title.isEmpty ? query : title, snippet: snippet)
            }
        } catch { return [] }
    }

    private func wikipedia(_ query: String) async -> [ResearchResult] {
        for language in ["zh", "en"] {
            do {
                var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
                components.queryItems = [URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "list", value: "search"), URLQueryItem(name: "srsearch", value: query), URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "utf8", value: "1"), URLQueryItem(name: "srlimit", value: "4")]
                let raw = try jsonObject(try await get(components.url!, timeout: 12))
                let queryObject = raw["query"] as? [String: Any] ?? [:]
                let items = queryObject["search"] as? [[String: Any]] ?? []
                let results: [ResearchResult] = items.compactMap { item in
                    let title = stringValue(item["title"])
                    guard !title.isEmpty else { return nil }
                    let snippet = stringValue(item["snippet"]).replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    let slug = title.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
                    return ResearchResult(title: title, snippet: snippet, url: "https://\(language).wikipedia.org/wiki/\(slug)")
                }
                if !results.isEmpty { return results }
            } catch { continue }
        }
        return []
    }

    private func webSources(_ query: String, maxResults: Int) async -> [ResearchResult] {
        do { let result = try await serper(query, maxResults: maxResults); if !result.isEmpty { return result } } catch {}
        let wiki = await wikipedia(query)
        if !wiki.isEmpty { return Array(wiki.prefix(maxResults)) }
        let instant = await duckDuckGoInstant(query)
        if !instant.isEmpty { return Array(instant.prefix(maxResults)) }
        return await duckDuckGoLite(query, maxResults: maxResults)
    }

    private func deduplicate(_ results: [ResearchResult]) -> [ResearchResult] {
        var seen = Set<String>(), output: [ResearchResult] = []
        for result in results {
            let key = String(result.title.prefix(40)) + "|" + String(result.snippet.prefix(60))
            if seen.insert(key).inserted { output.append(result) }
        }
        return output
    }

    public func search(_ query: String, maxResults: Int = 5, mode: String = "auto") async -> [ResearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, maxResults > 0 else { return [] }
        let normalizedMode = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let wantBoth = normalizedMode == "both"
        var merged: [ResearchResult] = []
        for source in resolveSearchModes(query: q, mode: mode) {
            if source == "xiaohongshu" {
                let result = await xiaohongshu.searchFeeds(q, maxResults: maxResults).results
                merged.append(contentsOf: result)
            } else {
                merged.append(contentsOf: await webSources(q, maxResults: maxResults))
            }
            if !merged.isEmpty && !wantBoth { break }
            if wantBoth && merged.count >= maxResults { break }
        }
        return Array(deduplicate(merged).prefix(maxResults))
    }

    public func formatResultsForPrompt(_ query: String, results: [ResearchResult]) -> String {
        guard !results.isEmpty else { return "（关于「\(query)」暂未搜到有效摘要）" }
        return results.enumerated().map { index, result in
            let title = result.title.isEmpty ? query : result.title
            let tag = result.source == "xiaohongshu" ? "📕" : "🌐"
            var line = "\(index + 1). \(tag) \(title)：\(result.snippet)"
            if !result.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { line += "（\(result.url)）" }
            return line
        }.joined(separator: "\n")
    }
}
