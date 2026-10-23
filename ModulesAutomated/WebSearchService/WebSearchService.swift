import Foundation

public struct WebSearchResult: Codable, Sendable, Equatable {
    public var title: String
    public var snippet: String
    public var url: String
    public var source: String

    public init(title: String, snippet: String, url: String = "", source: String = "web") {
        self.title = title; self.snippet = snippet; self.url = url; self.source = source
    }
}

public struct WebSearchBias: Codable, Sendable, Equatable {
    public let xiaohongshu: Int
    public let web: Int
    public init(xiaohongshu: Int, web: Int) { self.xiaohongshu = xiaohongshu; self.web = web }
}

public struct WebSearchXHSStatus: Codable, Sendable, Equatable {
    public var configured: Bool
    public var baseURL: String
    public var hasAuthToken: Bool
    public var reachable: Bool
    public var loggedIn: Bool
    public var username: String
    public var error: String
}

public struct WebSearchImageCandidate: Codable, Sendable, Equatable {
    public var imageUrl: String
    public var title: String
    public var feedId: String
    public var xsecToken: String
    public var noteUrl: String
    public var noteType: String
    public var source: String
}

public struct WebSearchConfiguration: Sendable {
    public var serperAPIKey: String
    public var xhsBaseURL: URL
    public var xhsAuthToken: String
    public var timeout: TimeInterval
    public var maximumResponseBytes: Int
    public var userAgent: String

    public init(serperAPIKey: String = "", xhsBaseURL: URL? = nil, xhsAuthToken: String = "",
                timeout: TimeInterval = 15, maximumResponseBytes: Int = 2_000_000,
                userAgent: String = "Mozilla/5.0 (compatible; WebSearchService/1.0)") {
        self.serperAPIKey = serperAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = URL(string: "http://127.0.0.1:18060")!
        let candidate = xhsBaseURL ?? fallback
        self.xhsBaseURL = Self.validBase(candidate) ? candidate : fallback
        self.xhsAuthToken = xhsAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = min(60, max(1, timeout))
        self.maximumResponseBytes = min(16_000_000, max(1024, maximumResponseBytes))
        self.userAgent = userAgent.isEmpty ? "WebSearchService/1.0" : userAgent
    }

    public static func environment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        let raw = (env["XHS_MCP_BASE_URL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(serperAPIKey: env["SERPER_API_KEY"] ?? "",
                    xhsBaseURL: raw.isEmpty ? nil : URL(string: raw),
                    xhsAuthToken: env["XHS_MCP_AUTH_TOKEN"] ?? "")
    }

    public static func validBase(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = c.scheme?.lowercased(), let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              scheme == "https" || (scheme == "http" && isLoopback(host)) else { return false }
        return true
    }

    private static func isLoopback(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "localhost" || h == "::1" || h == "127.0.0.1" || h.hasPrefix("127.")
    }
}

public enum WebSearchError: Error, LocalizedError {
    case invalidURL
    case responseTooLarge
    case invalidResponse
    case httpStatus(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid or unsafe provider URL"
        case .responseTooLarge: return "Search response exceeded configured byte limit"
        case .invalidResponse: return "Provider returned an invalid response"
        case .httpStatus(let code, _): return "Search provider returned HTTP \(code)"
        }
    }
}

public struct WebSearchHTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public init(data: Data, statusCode: Int) { self.data = data; self.statusCode = statusCode }
}

public protocol WebSearchHTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> WebSearchHTTPResponse
}

/// Default Foundation transport. The post-download size check bounds accepted payloads; URLSession
/// buffers the transfer before returning, so deployments facing hostile endpoints should inject a
/// streaming transport that aborts as soon as the byte limit is exceeded.
public struct URLSessionWebSearchTransport: WebSearchHTTPTransport {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest, maximumBytes: Int) async throws -> WebSearchHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard data.count <= maximumBytes else { throw WebSearchError.responseTooLarge }
        guard let http = response as? HTTPURLResponse else { throw WebSearchError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw WebSearchError.httpStatus(http.statusCode, String(decoding: data.prefix(240), as: UTF8.self))
        }
        return WebSearchHTTPResponse(data: data, statusCode: http.statusCode)
    }
}

public struct WebSearchService: Sendable {
    public let configuration: WebSearchConfiguration
    public let transport: any WebSearchHTTPTransport

    public init(configuration: WebSearchConfiguration = .environment(),
                transport: any WebSearchHTTPTransport = URLSessionWebSearchTransport()) {
        self.configuration = configuration; self.transport = transport
    }

    private static let xhsPattern = #"小红书|种草|探店|穿搭|美妆|护肤|口红|咖啡|餐厅|美食|旅游|旅行|民宿|攻略|好物|安利|vlog|打卡|拍照|相机|健身餐|减脂餐|下午茶|甜品|火锅|酒吧|展览|市集|露营|徒步|温泉|酒店|机票|签证|平价|测评|推荐|哪里好玩|去哪玩|吃什么|怎么拍"#
    private static let webPattern = #"新闻|天气|气温|降雨|股价|汇率|发布|上市|版本|官宣|百科|维基|官网|下载|更新日志|changelog|API|github|stackoverflow|什么时候|几点|今年|昨天|今天|最近发生|地震|台风|谁赢了|比分|冠军|选举|政策|法规|疫情|[?？].*(什么|怎么|为什么|何时|哪里|多少|是否)"#
    private static let entityPattern = #"《[^》]{2,}》|[A-Za-z][A-Za-z0-9._-]{2,}|乐队|专辑|单曲|电影|剧集|动漫|游戏|角色|cv|声优"#

    private func count(_ pattern: String, _ text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    public func inferSearchBias(_ query: String) -> WebSearchBias {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return WebSearchBias(xiaohongshu: 0, web: 0) }
        var x = count(Self.xhsPattern, q), w = count(Self.webPattern, q)
        if count(Self.entityPattern, q) > 0 { w += 1 }
        if q.count <= 12 && w == 0 { x += 1 }
        return WebSearchBias(xiaohongshu: x, web: w)
    }

    public func resolveSearchModes(query: String, mode: String = "auto") -> [String] {
        switch mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "xiaohongshu": return ["xiaohongshu", "web"]
        case "web": return ["web", "xiaohongshu"]
        case "both": return ["xiaohongshu", "web"]
        default:
            guard configuration.xhsBaseURL.host != nil else { return ["web"] }
            let bias = inferSearchBias(query)
            return bias.web > bias.xiaohongshu ? ["web", "xiaohongshu"] : ["xiaohongshu", "web"]
        }
    }

    private func request(_ url: URL, method: String = "GET", body: Data? = nil,
                         headers: [String: String] = [:], timeout: TimeInterval? = nil) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout ?? configuration.timeout)
        req.httpMethod = method; req.httpBody = body
        req.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        return req
    }

    private func fetch(_ url: URL, method: String = "GET", body: Data? = nil,
                       headers: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> Data {
        let response = try await transport.send(request(url, method: method, body: body, headers: headers, timeout: timeout),
                                                maximumBytes: configuration.maximumResponseBytes)
        return response.data
    }

    private func json(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw WebSearchError.invalidResponse }
        return object
    }

    private func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func serper(_ query: String, limit: Int) async throws -> [WebSearchResult] {
        guard !configuration.serperAPIKey.isEmpty else { return [] }
        let url = URL(string: "https://google.serper.dev/search")!
        let body = try JSONSerialization.data(withJSONObject: ["q": query, "num": limit])
        let raw = try json(await fetch(url, method: "POST", body: body,
                                       headers: ["X-API-KEY": configuration.serperAPIKey, "Content-Type": "application/json"], timeout: 20))
        return (raw["organic"] as? [[String: Any]] ?? []).prefix(limit).map {
            WebSearchResult(title: string($0["title"]), snippet: string($0["snippet"]), url: string($0["link"]))
        }
    }

    private func wikipedia(_ query: String) async -> [WebSearchResult] {
        for lang in ["zh", "en"] {
            do {
                var c = URLComponents(string: "https://\(lang).wikipedia.org/w/api.php")!
                c.queryItems = [URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "list", value: "search"),
                                URLQueryItem(name: "srsearch", value: query), URLQueryItem(name: "format", value: "json"),
                                URLQueryItem(name: "utf8", value: "1"), URLQueryItem(name: "srlimit", value: "4")]
                let raw = try json(await fetch(c.url!, timeout: 12))
                let items = ((raw["query"] as? [String: Any])?["search"] as? [[String: Any]]) ?? []
                let results = items.compactMap { item -> WebSearchResult? in
                    let title = string(item["title"]); guard !title.isEmpty else { return nil }
                    let snippet = string(item["snippet"]).replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    var slug = URLComponents(); slug.path = "/" + title.replacingOccurrences(of: " ", with: "_")
                    let encoded = slug.percentEncodedPath
                    return WebSearchResult(title: title, snippet: snippet, url: "https://\(lang).wikipedia.org/wiki" + encoded)
                }
                if !results.isEmpty { return results }
            } catch { continue }
        }
        return []
    }

    private func duckDuckGoInstant(_ query: String) async -> [WebSearchResult] {
        do {
            var c = URLComponents(string: "https://api.duckduckgo.com/")!
            c.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "format", value: "json"),
                            URLQueryItem(name: "no_html", value: "1"), URLQueryItem(name: "skip_disambig", value: "1")]
            let raw = try json(await fetch(c.url!, timeout: 12))
            var out: [WebSearchResult] = []
            let abstract = string(raw["AbstractText"])
            if !abstract.isEmpty { out.append(.init(title: string(raw["Heading"]).isEmpty ? query : string(raw["Heading"]), snippet: abstract, url: string(raw["AbstractURL"]))) }
            for topic in (raw["RelatedTopics"] as? [[String: Any]] ?? []).prefix(4) where !string(topic["Text"]).isEmpty {
                out.append(.init(title: query, snippet: string(topic["Text"]), url: string(topic["FirstURL"])))
            }
            return out
        } catch { return [] }
    }

    private func decodeHTML(_ value: String) -> String {
        var decoded = value
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        let pattern = #"&#(?:x([0-9a-fA-F]+)|([0-9]+));?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return decoded }
        let ns = decoded as NSString
        let matches = regex.matches(in: decoded, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            let raw: String
            let radix: Int
            if match.range(at: 1).location != NSNotFound {
                raw = ns.substring(with: match.range(at: 1)); radix = 16
            } else {
                raw = ns.substring(with: match.range(at: 2)); radix = 10
            }
            guard let scalarValue = UInt32(raw, radix: radix), let scalar = Unicode.Scalar(scalarValue) else { continue }
            decoded = (decoded as NSString).replacingCharacters(in: match.range, with: String(scalar))
        }
        return decoded
    }

    private func duckDuckGoLite(_ query: String, limit: Int) async -> [WebSearchResult] {
        do {
            var c = URLComponents(); c.queryItems = [URLQueryItem(name: "q", value: query)]
            let body = (c.percentEncodedQuery ?? "").data(using: .utf8)
            let data = try await fetch(URL(string: "https://lite.duckduckgo.com/lite/")!, method: "POST", body: body,
                                       headers: ["Content-Type": "application/x-www-form-urlencoded"], timeout: 18)
            let html = String(decoding: data, as: UTF8.self)
            let pattern = #"<a(?=[^>]*class="result-link")(?=[^>]*href="([^"]+)")[^>]*>([^<]+)</a>.*?class="result-snippet"[^>]*>(.*?)</"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let range = NSRange(html.startIndex..., in: html)
            return regex.matches(in: html, range: range).prefix(limit).compactMap { m in
                guard let hrefRange = Range(m.range(at: 1), in: html),
                      let titleRange = Range(m.range(at: 2), in: html),
                      let snippetRange = Range(m.range(at: 3), in: html) else { return nil }
                let title = decodeHTML(String(html[titleRange]))
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = decodeHTML(String(html[snippetRange]))
                    .replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
                    .replacingOccurrences(of: #"\\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let href = decodeHTML(String(html[hrefRange]))
                let resolvedURL: String
                if let components = URLComponents(string: href),
                   let redirect = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
                   let target = URL(string: redirect), ["http", "https"].contains(target.scheme?.lowercased() ?? ""),
                   target.host != nil {
                    resolvedURL = target.absoluteString
                } else if let target = URL(string: href, relativeTo: URL(string: "https://lite.duckduckgo.com/lite/")?.absoluteURL),
                          ["http", "https"].contains(target.scheme?.lowercased() ?? ""), target.host != nil {
                    resolvedURL = target.absoluteURL.absoluteString
                } else {
                    resolvedURL = ""
                }
                guard !title.isEmpty || !snippet.isEmpty else { return nil }
                return WebSearchResult(title: title.isEmpty ? query : title, snippet: snippet, url: resolvedURL)
            }
        } catch { return [] }
    }

    private func xhs(_ query: String, limit: Int) async -> [WebSearchResult] {
        guard WebSearchConfiguration.validBase(configuration.xhsBaseURL) else { return [] }
        let url = configuration.xhsBaseURL.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("feeds").appendingPathComponent("search")
        guard let body = try? JSONSerialization.data(withJSONObject: ["keyword": query]) else { return [] }
        var headers = ["Accept": "application/json", "Content-Type": "application/json"]
        if !configuration.xhsAuthToken.isEmpty { headers["Authorization"] = "Bearer " + configuration.xhsAuthToken }
        do {
            let raw = try json(await fetch(url, method: "POST", body: body, headers: headers, timeout: 45))
            guard (raw["success"] as? Bool) == true else { return [] }
            let feeds = (((raw["data"] as? [String: Any])?["feeds"]) as? [[String: Any]]) ?? []
            return feeds.prefix(limit).compactMap { feed in
                let card = feed["noteCard"] as? [String: Any] ?? [:]
                let id = string(feed["id"])
                let title = [string(card["displayTitle"]), string(card["title"])].first(where: { !$0.isEmpty }) ?? "小红书笔记 \(id.prefix(8))"
                let user = card["user"] as? [String: Any] ?? [:]
                let interact = card["interactInfo"] as? [String: Any] ?? [:]
                let nickname = [string(user["nickname"]), string(user["nickName"])].first(where: { !$0.isEmpty }) ?? "未知作者"
                let kind = string(card["type"]) == "video" || card["video"] != nil ? "视频" : "图文"
                var desc = [string(card["desc"]), string(card["content"])].first(where: { !$0.isEmpty }) ?? ""
                desc = desc.replacingOccurrences(of: "\n", with: " ")
                if desc.count > 120 { desc = String(desc.prefix(120)) }
                let snippet = "作者 \(nickname) · \(kind) · 👍\(string(interact["likedCount"]).isEmpty ? "0" : string(interact["likedCount"])) ⭐\(string(interact["collectedCount"]).isEmpty ? "0" : string(interact["collectedCount"])) 💬\(string(interact["commentCount"]).isEmpty ? "0" : string(interact["commentCount"]))" + (desc.isEmpty ? "" : " — " + desc)
                let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
                return WebSearchResult(title: title, snippet: snippet, url: id.isEmpty ? "" : "https://www.xiaohongshu.com/explore/" + safeID, source: "xiaohongshu")
            }
        } catch { return [] }
    }

    private func webSources(_ query: String, limit: Int) async -> [WebSearchResult] {
        do { let r = try await serper(query, limit: limit); if !r.isEmpty { return r } } catch {}
        let wiki = await wikipedia(query); if !wiki.isEmpty { return Array(wiki.prefix(limit)) }
        let instant = await duckDuckGoInstant(query); if !instant.isEmpty { return Array(instant.prefix(limit)) }
        return await duckDuckGoLite(query, limit: limit)
    }

    private func xhsRequest(_ path: String, method: String = "GET", payload: [String: Any]? = nil) async throws -> [String: Any] {
        guard WebSearchConfiguration.validBase(configuration.xhsBaseURL) else { throw WebSearchError.invalidURL }
        let url = path.split(separator: "/").map(String.init).reduce(configuration.xhsBaseURL) { $0.appendingPathComponent($1) }
        let body = try payload.map { try JSONSerialization.data(withJSONObject: $0) }
        var headers = ["Accept": "application/json", "Content-Type": "application/json"]
        if !configuration.xhsAuthToken.isEmpty { headers["Authorization"] = "Bearer " + configuration.xhsAuthToken }
        return try json(await fetch(url, method: method, body: body, headers: headers, timeout: 45))
    }

    public func xiaohongshuStatus() async -> WebSearchXHSStatus {
        var status = WebSearchXHSStatus(configured: WebSearchConfiguration.validBase(configuration.xhsBaseURL),
                                        baseURL: configuration.xhsBaseURL.absoluteString,
                                        hasAuthToken: !configuration.xhsAuthToken.isEmpty,
                                        reachable: false, loggedIn: false, username: "", error: "")
        do {
            let health = try await xhsRequest("health")
            status.reachable = (health["success"] as? Bool) == true
            let login = try await xhsRequest("api/v1/login/status")
            let data = login["data"] as? [String: Any] ?? [:]
            status.loggedIn = (data["is_logged_in"] as? Bool) == true
            status.username = string(data["username"])
            if !status.loggedIn { status.error = "小红书 MCP 已连通，但尚未登录（需运行 xiaohongshu-login 扫码）" }
        } catch { status.error = error.localizedDescription }
        return status
    }

    public func searchImageCandidates(_ keyword: String, maxResults: Int = 5,
                                      preferImageNotes: Bool = true) async -> (results: [WebSearchImageCandidate], error: String?) {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, maxResults > 0 else { return ([], "关键词为空或结果数量无效") }
        do {
            let raw = try await xhsRequest("api/v1/feeds/search", method: "POST", payload: ["keyword": q])
            guard (raw["success"] as? Bool) == true else {
                let message = string(raw["message"]), error = string(raw["error"])
                return ([], !message.isEmpty ? message : (!error.isEmpty ? error : "搜索失败"))
            }
            let feeds = (((raw["data"] as? [String: Any])?["feeds"]) as? [[String: Any]]) ?? []
            var chosen: [WebSearchImageCandidate] = [], deferred: [WebSearchImageCandidate] = []
            for feed in feeds {
                let card = feed["noteCard"] as? [String: Any] ?? [:]
                let cover = card["cover"]
                var urls: [String] = []
                if let s = cover as? String { urls.append(s) }
                if let c = cover as? [String: Any] {
                    for key in ["url", "urlDefault", "urlPre"] { urls.append(string(c[key])) }
                    for item in c["infoList"] as? [[String: Any]] ?? [] { urls.append(string(item["url"])) }
                }
                guard let rawURL = urls.first(where: { $0.hasPrefix("https://") || $0.hasPrefix("http://") }),
                      var parts = URLComponents(string: rawURL),
                      let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
                      parts.host != nil else { continue }
                if scheme == "http" { parts.scheme = "https" }
                guard let imageURL = parts.url?.absoluteString else { continue }
                let id = string(feed["id"])
                let title = [string(card["displayTitle"]), string(card["title"])].first(where: { !$0.isEmpty }) ?? "小红书笔记 \(id.prefix(8))"
                let video = card["video"] != nil || string(card["type"]) == "video"
                let noteURL = id.isEmpty ? "" : "https://www.xiaohongshu.com/explore/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
                let item = WebSearchImageCandidate(imageUrl: imageURL, title: title, feedId: id, xsecToken: string(feed["xsecToken"]), noteUrl: noteURL, noteType: video ? "video" : "normal", source: "xiaohongshu")
                if preferImageNotes && video { deferred.append(item) } else { chosen.append(item) }
                if chosen.count >= maxResults { break }
            }
            if chosen.count < maxResults { chosen.append(contentsOf: deferred.prefix(maxResults - chosen.count)) }
            return (Array(chosen.prefix(maxResults)), nil)
        } catch { return ([], error.localizedDescription) }
    }

    private func deduplicate(_ results: [WebSearchResult]) -> [WebSearchResult] {
        var seen = Set<String>(), out: [WebSearchResult] = []
        for r in results {
            let key = String(r.title.prefix(40)) + "|" + String(r.snippet.prefix(60))
            if seen.insert(key).inserted { out.append(r) }
        }
        return out
    }

    public func search(_ query: String, maxResults: Int = 5, mode: String = "auto") async -> [WebSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, maxResults > 0 else { return [] }
        let limit = min(maxResults, 50), both = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "both"
        var merged: [WebSearchResult] = []
        for source in resolveSearchModes(query: q, mode: mode) {
            if source == "xiaohongshu" {
                merged.append(contentsOf: await xhs(q, limit: limit))
            } else {
                merged.append(contentsOf: await webSources(q, limit: limit))
            }
            if !both && !merged.isEmpty { break }
            // Explicit "both" means query both provider groups even if the first fills the cap.
        }
        return Array(deduplicate(merged).prefix(limit))
    }

    public func formatResultsForPrompt(_ query: String, results: [WebSearchResult]) -> String {
        guard !results.isEmpty else { return "（关于「\(query)」暂未搜到有效摘要）" }
        return results.enumerated().map { index, r in
            let title = r.title.isEmpty ? query : r.title
            var line = "\(index + 1). \(r.source == "xiaohongshu" ? "📕" : "🌐") \(title)：\(r.snippet)"
            if !r.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { line += "（\(r.url)）" }
            return line
        }.joined(separator: "\n")
    }
}
