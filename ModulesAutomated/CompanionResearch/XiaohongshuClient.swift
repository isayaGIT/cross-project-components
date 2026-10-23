import Foundation

public struct XiaohongshuClient: Sendable {
    public let configuration: ResearchConfiguration
    public let transport: any ResearchHTTPTransport

    public init(configuration: ResearchConfiguration = .environment(), transport: any ResearchHTTPTransport = URLSessionResearchTransport()) {
        self.configuration = configuration; self.transport = transport
    }

    public func isConfigured() -> Bool { configuration.xhsBaseURL.host != nil }
    public func baseURL() -> String { configuration.xhsBaseURL.absoluteString }
    public func authToken() -> String { configuration.xhsAuthToken }

    private func headers() -> [String: String] {
        var result = ["Content-Type": "application/json", "Accept": "application/json", "User-Agent": configuration.userAgent]
        if !configuration.xhsAuthToken.isEmpty { result["Authorization"] = "Bearer " + configuration.xhsAuthToken }
        return result
    }

    private func apiGet(_ path: String) async throws -> [String: Any] {
        let url = configuration.xhsBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        let response = try await transport.send(makeRequest(url: url, headers: headers(), timeout: 45), maximumBytes: configuration.maximumResponseBytes)
        return try jsonObject(response.data)
    }

    private func apiPost(_ path: String, payload: [String: Any]) async throws -> [String: Any] {
        let url = configuration.xhsBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response = try await transport.send(makeRequest(url: url, method: "POST", body: body, headers: headers(), timeout: 45), maximumBytes: configuration.maximumResponseBytes)
        return try jsonObject(response.data)
    }

    public func status() async -> XHSStatus {
        var result = XHSStatus(configured: isConfigured(), baseURL: baseURL(), hasAuthToken: !authToken().isEmpty, reachable: false, loggedIn: false, username: "", error: "")
        do {
            let health = try await apiGet("health")
            result.reachable = (health["success"] as? Bool) ?? false
            let login = try await apiGet("api/v1/login/status")
            let data = login["data"] as? [String: Any] ?? [:]
            result.loggedIn = (data["is_logged_in"] as? Bool) ?? false
            result.username = stringValue(data["username"])
            if !result.loggedIn { result.error = "小红书 MCP 已连通，但尚未登录（需运行 xiaohongshu-login 扫码）" }
        } catch { result.error = error.localizedDescription }
        return result
    }

    private func feedTitle(_ feed: [String: Any]) -> String {
        let card = feed["noteCard"] as? [String: Any] ?? [:]
        let title = stringValue(card["displayTitle"]).isEmpty ? stringValue(card["title"]) : stringValue(card["displayTitle"])
        if !title.isEmpty { return title }
        let identifier = stringValue(feed["id"])
        return "小红书笔记 \(String(identifier.prefix(8)))".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func feedSnippet(_ feed: [String: Any]) -> String {
        let card = feed["noteCard"] as? [String: Any] ?? [:]
        let user = card["user"] as? [String: Any] ?? [:]
        let nickname = stringValue(user["nickname"]).isEmpty ? (stringValue(user["nickName"]).isEmpty ? "未知作者" : stringValue(user["nickName"])) : stringValue(user["nickname"])
        let interact = card["interactInfo"] as? [String: Any] ?? [:]
        let liked = stringValue(interact["likedCount"]).isEmpty ? "0" : stringValue(interact["likedCount"])
        let collected = stringValue(interact["collectedCount"]).isEmpty ? "0" : stringValue(interact["collectedCount"])
        let comments = stringValue(interact["commentCount"]).isEmpty ? "0" : stringValue(interact["commentCount"])
        let isVideo = stringValue(card["type"]) == "video" || card["video"] != nil
        var description = stringValue(card["desc"]).isEmpty ? stringValue(card["content"]) : stringValue(card["desc"])
        description = description.replacingOccurrences(of: "\n", with: " ")
        if description.count > 120 { description = String(description.prefix(120)) }
        let base = "作者 \(nickname) · \(isVideo ? "视频" : "图文") · 👍\(liked) ⭐\(collected) 💬\(comments)"
        return description.isEmpty ? base : base + " — " + description
    }

    private func feedURL(_ feed: [String: Any]) -> String {
        let identifier = stringValue(feed["id"])
        guard !identifier.isEmpty else { return "" }
        var components = URLComponents(string: "https://www.xiaohongshu.com/explore/")!
        components.path += identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? identifier
        return components.string ?? ""
    }

    public func feedsToResults(_ feeds: [[String: Any]], maxResults: Int = 5) -> [ResearchResult] {
        feeds.prefix(max(0, maxResults)).compactMap { feed in
            let title = feedTitle(feed), snippet = feedSnippet(feed)
            guard !title.isEmpty || !snippet.isEmpty else { return nil }
            return ResearchResult(title: title, snippet: snippet, url: feedURL(feed), source: "xiaohongshu")
        }
    }

    private func coverURL(_ feed: [String: Any]) -> String {
        let card = feed["noteCard"] as? [String: Any] ?? [:]
        let cover = card["cover"]
        var candidates: [String] = []
        if let value = cover as? String { candidates.append(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let object = cover as? [String: Any] {
            ["url", "urlDefault", "urlPre"].forEach { candidates.append(stringValue(object[$0])) }
            for info in object["infoList"] as? [[String: Any]] ?? [] { candidates.append(stringValue(info["url"])) }
        }
        for candidate in candidates where candidate.hasPrefix("https://") || candidate.hasPrefix("http://") {
            if candidate.hasPrefix("http://") { return "https://" + candidate.dropFirst("http://".count) }
            return candidate
        }
        return ""
    }

    private func rawFeeds(_ keyword: String) async throws -> [[String: Any]] {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty, isConfigured() else { throw ResearchError.invalidResponse("小红书 MCP 未配置或关键词为空") }
        let raw = try await apiPost("api/v1/feeds/search", payload: ["keyword": keyword])
        guard (raw["success"] as? Bool) == true else {
            throw ResearchError.invalidResponse(stringValue(raw["message"]).isEmpty ? (stringValue(raw["error"]).isEmpty ? "搜索失败" : stringValue(raw["error"])) : stringValue(raw["message"]))
        }
        let data = raw["data"] as? [String: Any] ?? [:]
        return data["feeds"] as? [[String: Any]] ?? []
    }

    public func searchFeeds(_ keyword: String, maxResults: Int = 5) async -> (results: [ResearchResult], error: String?) {
        do { return (feedsToResults(try await rawFeeds(keyword), maxResults: maxResults), nil) }
        catch { return ([], error.localizedDescription) }
    }

    public func searchImageCandidates(_ keyword: String, maxResults: Int = 5, preferImageNotes: Bool = true) async -> (results: [ImageCandidate], error: String?) {
        do {
            let feeds = try await rawFeeds(keyword)
            var selected: [ImageCandidate] = [], deferredVideos: [ImageCandidate] = []
            for feed in feeds {
                let image = coverURL(feed)
                guard !image.isEmpty else { continue }
                let card = feed["noteCard"] as? [String: Any] ?? [:]
                let video = card["video"] != nil || stringValue(card["type"]) == "video"
                let item = ImageCandidate(imageUrl: image, title: feedTitle(feed), feedId: stringValue(feed["id"]), xsecToken: stringValue(feed["xsecToken"]), noteUrl: feedURL(feed), noteType: video ? "video" : "normal", source: "xiaohongshu")
                if preferImageNotes && video { deferredVideos.append(item) } else { selected.append(item) }
                if selected.count >= maxResults { break }
            }
            if selected.count < maxResults { selected.append(contentsOf: deferredVideos.prefix(maxResults - selected.count)) }
            return (Array(selected.prefix(max(0, maxResults))), nil)
        } catch { return ([], error.localizedDescription) }
    }
}
