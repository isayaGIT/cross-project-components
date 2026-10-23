import Foundation

public protocol ResearchFileStore: Sendable {
    func write(_ data: Data, filename: String, to directory: URL) throws
}

public struct LocalResearchFileStore: ResearchFileStore {
    public init() {}
    public func write(_ data: Data, filename: String, to directory: URL) throws {
        guard !filename.contains("/") && !filename.contains("\\") && filename != "." && filename != ".." else { throw ResearchError.storage("Invalid filename") }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        } catch { throw ResearchError.storage(error.localizedDescription) }
    }
}

public struct ImageSearchService: Sendable {
    public typealias SafeURLCheck = @Sendable (URL) -> Bool
    public typealias ImageTypeDetector = @Sendable (Data) -> (mime: String?, extension: String?)

    public let configuration: ResearchConfiguration
    public let transport: any ResearchHTTPTransport
    public let xiaohongshu: XiaohongshuClient
    public let fileStore: any ResearchFileStore
    public let isSafeURL: SafeURLCheck
    public let detectImageType: ImageTypeDetector

    public init(configuration: ResearchConfiguration = .environment(), transport: any ResearchHTTPTransport = URLSessionResearchTransport(), xiaohongshu: XiaohongshuClient? = nil, fileStore: any ResearchFileStore = LocalResearchFileStore(), isSafeURL: @escaping SafeURLCheck, detectImageType: @escaping ImageTypeDetector) {
        self.configuration = configuration; self.transport = transport
        self.xiaohongshu = xiaohongshu ?? XiaohongshuClient(configuration: configuration, transport: transport)
        self.fileStore = fileStore; self.isSafeURL = isSafeURL; self.detectImageType = detectImageType
    }

    public func searchAndDownload(query: String, saveDirectory: URL, maxCandidates: Int = 5) async -> ImageSearchResult {
        guard !configuration.imageSearchDisabled else { return .failure("搜图试验已关闭（IMAGE_SEARCH_DISABLED）") }
        var q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return .failure("请填写搜图关键词") }
        if q.count > 200 { q = String(q.prefix(200)) }
        let status = await xiaohongshu.status()
        guard status.reachable else { return .failure("小红书 MCP 连不上（请本机启动并设置 XHS_MCP_BASE_URL）。" + status.error) }
        guard status.loggedIn else { return .failure("小红书 MCP 未登录，请先扫码登录后再试。") }
        let found = await xiaohongshu.searchImageCandidates(q, maxResults: maxCandidates)
        if let error = found.error { return .failure("搜图失败：" + error) }
        guard !found.results.isEmpty else { return .failure("没搜到可用图片，换个关键词试试") }

        var lastError = ""
        for candidate in found.results {
            guard let url = URL(string: candidate.imageUrl), url.scheme?.lowercased() == "https", isSafeURL(url) else {
                lastError = "封面地址不安全或无效"; continue
            }
            do {
                let request = makeRequest(url: url, headers: ["User-Agent": configuration.userAgent, "Referer": "https://www.xiaohongshu.com/", "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"], timeout: 45)
                let data = try await transport.send(request, maximumBytes: configuration.maximumImageBytes).data
                guard data.count >= 200 else { lastError = "下载的图片过小"; continue }
                let detected = detectImageType(data)
                guard let mime = detected.mime, mime.hasPrefix("image/") else { lastError = "不是有效图片"; continue }
                var ext = detected.extension ?? ".jpg"
                if !ext.hasPrefix(".") { ext = "." + ext }
                let filename = "xhs_" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12)) + ext
                do { try fileStore.write(data, filename: filename, to: saveDirectory) }
                catch { return .failure("保存失败：" + error.localizedDescription) }
                return ImageSearchResult(status: "ok", filename: filename, prompt: q, title: candidate.title, source: "xiaohongshu", noteUrl: candidate.noteUrl, noteType: candidate.noteType)
            } catch { lastError = error.localizedDescription }
        }
        return .failure("图片下载失败：" + (lastError.isEmpty ? "未知错误" : lastError))
    }
}
