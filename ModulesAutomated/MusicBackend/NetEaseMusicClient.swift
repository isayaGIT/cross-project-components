import Foundation

public struct NetEaseMusicConfiguration: Sendable {
    public static let defaultBaseURL = URL(string: "https://netease.xbattle.tech")!
    public var baseURL: URL
    public var cookie: String
    public var timeout: TimeInterval

    public init(baseURL: URL = NetEaseMusicConfiguration.defaultBaseURL, cookie: String = "", timeout: TimeInterval = 15) {
        self.baseURL = baseURL
        self.cookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> NetEaseMusicConfiguration {
        let rawBase = (environment["NETEASE_MUSIC_BASE_URL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = URL(string: rawBase)
        let validScheme = candidate?.scheme?.lowercased() == "http" || candidate?.scheme?.lowercased() == "https"
        let base = validScheme ? candidate! : defaultBaseURL
        let cookie = (environment["NETEASE_MUSIC_COOKIE"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return NetEaseMusicConfiguration(baseURL: base, cookie: cookie)
    }

    public var isConfigured: Bool { !cookie.isEmpty }
}

public enum MusicBackendError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case httpStatus(Int, String)
    case invalidResponse(String)
    case transport(String)
    case api(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "网易云音乐 API 未配置，请设置 NETEASE_MUSIC_COOKIE"
        case .invalidURL: return "网易云音乐 API URL 无效"
        case .httpStatus(let code, let body): return "HTTP \(code): \(body)"
        case .invalidResponse(let detail): return detail
        case .transport(let detail): return detail
        case .api(let detail): return detail
        }
    }
}

public struct NetEaseMusicStatus: Codable, Equatable, Sendable {
    public let configured: Bool
    public let baseURL: String
    public let hasCookie: Bool

    public init(configured: Bool, baseURL: String, hasCookie: Bool) {
        self.configured = configured
        self.baseURL = baseURL
        self.hasCookie = hasCookie
    }
}

public protocol MusicHTTPTransport {
    func get(_ request: URLRequest, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionMusicHTTPTransport: MusicHTTPTransport {
    public var session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func get(_ request: URLRequest, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicBackendError.invalidResponse("Invalid HTTP response")
        }
        return (data, http)
    }
}

public final class NetEaseMusicClient {
    public let configuration: NetEaseMusicConfiguration
    private let transport: MusicHTTPTransport
    private let referer = "https://music.163.com/"

    public init(configuration: NetEaseMusicConfiguration = .fromEnvironment(), transport: MusicHTTPTransport = URLSessionMusicHTTPTransport()) {
        self.configuration = configuration
        self.transport = transport
    }

    public var status: NetEaseMusicStatus {
        NetEaseMusicStatus(configured: configuration.isConfigured, baseURL: configuration.baseURL.absoluteString, hasCookie: !configuration.cookie.isEmpty)
    }

    private func apiGet(_ path: String, query: [(String, String)] = []) async throws -> JSONValue {
        guard configuration.isConfigured else { throw MusicBackendError.notConfigured }
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw MusicBackendError.invalidURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        let relativePath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath + relativePath
        var queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        queryItems.append(URLQueryItem(name: "cookie", value: configuration.cookie))
        components.queryItems = queryItems
        guard let url = components.url else { throw MusicBackendError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.timeout
        request.setValue(referer, forHTTPHeaderField: "Referer")
        do {
            let (data, response) = try await transport.get(request, timeout: configuration.timeout)
            guard (200..<300).contains(response.statusCode) else {
                let body = String(decoding: data, as: UTF8.self).prefix(200)
                throw MusicBackendError.httpStatus(response.statusCode, String(body))
            }
            do {
                return try JSONValue.decodeJSON(from: data)
            } catch {
                throw MusicBackendError.invalidResponse(error.localizedDescription)
            }
        } catch let error as MusicBackendError {
            throw error
        } catch {
            throw MusicBackendError.transport(error.localizedDescription)
        }
    }

    private func object(_ value: JSONValue) -> [String: JSONValue] { value.objectValue ?? [:] }
    private func firstArray(_ object: [String: JSONValue], keys: [String]) -> [JSONValue] {
        for key in keys { if let array = object[key]?.arrayValue { return array } }
        return []
    }

    public func searchSongs(keyword: String, limit: Int = 30) async throws -> [NetEaseSong] {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw MusicBackendError.api("请输入搜索关键词") }
        let response = try await apiGet("/cloudsearch", query: [("keywords", term), ("type", "1"), ("limit", String(limit))])
        let root = object(response)
        let result = object(root["result"] ?? .null)
        return firstArray(result, keys: ["songs"]).compactMap(NetEaseSong.normalize)
    }

    public func playURL(songID: String) async throws -> String {
        do {
            let response = try await apiGet("/song/url/v1", query: [("id", songID), ("level", "exhigh")])
            if let url = Self.extractPlayableURL(response) { return url }
        } catch {
            // The source behavior intentionally falls back to the unblock endpoint after failures.
        }
        do {
            let response = try await apiGet("/song/url/v1", query: [("id", songID), ("level", "exhigh"), ("unblock", "true")])
            if let url = Self.extractPlayableURL(response) { return url }
        } catch {
            // Preserve the source-facing user message below rather than leaking endpoint details.
        }
        throw MusicBackendError.api("歌曲可能因版权限制无法播放，请检查网易云音乐 Cookie")
    }

    private static func extractPlayableURL(_ value: JSONValue) -> String? {
        let root = value.objectValue ?? [:]
        let data = root["data"]?.arrayValue ?? []
        for item in data {
            if let url = item.objectValue?["url"]?.stringValue, !url.isEmpty { return url }
        }
        if let url = root["url"]?.stringValue, !url.isEmpty { return url }
        return nil
    }

    public func songDetail(songID: String) async throws -> NetEaseSongDetail {
        let response = try await apiGet("/song/detail", query: [("ids", songID)])
        let root = object(response)
        let songs = firstArray(root, keys: ["songs"])
        guard let rawSong = songs.first, let song = NetEaseSong.normalize(rawSong) else {
            throw MusicBackendError.api("获取歌曲详情失败")
        }
        return NetEaseSongDetail(song: song, raw: rawSong)
    }

    public func playlistDetail(playlistID: String) async throws -> NetEasePlaylistDetail {
        let response = try await apiGet("/playlist/detail", query: [("id", playlistID)])
        let root = object(response)
        let playlist = object(root["playlist"] ?? .null)
        guard !playlist.isEmpty else { throw MusicBackendError.api("获取歌单详情失败") }
        let idValue = playlist["id"]
        let id = idValue?.stringValue ?? idValue?.intValue.map(String.init) ?? playlistID
        let name = playlist["name"]?.stringValue ?? ""
        let cover = playlist["coverImgUrl"]?.stringValue ?? playlist["coverImgUrl"]?.stringValue ?? ""
        let count = playlist["trackCount"]?.intValue ?? 0
        let tracks = firstArray(playlist, keys: ["tracks"]).compactMap(NetEaseSong.normalize)
        return NetEasePlaylistDetail(id: id, name: name, coverURL: cover, trackCount: count, tracks: tracks, raw: response)
    }
}
