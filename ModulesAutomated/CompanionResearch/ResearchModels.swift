import Foundation

public struct ResearchResult: Codable, Sendable, Equatable {
    public var title: String
    public var snippet: String
    public var url: String
    public var source: String

    public init(title: String, snippet: String, url: String = "", source: String = "web") {
        self.title = title
        self.snippet = snippet
        self.url = url
        self.source = source
    }
}

public struct SearchBias: Codable, Sendable, Equatable {
    public var xiaohongshu: Int
    public var web: Int
    public init(xiaohongshu: Int, web: Int) {
        self.xiaohongshu = xiaohongshu
        self.web = web
    }
}

public struct SearchIntent: Codable, Sendable, Equatable {
    public var shouldSearch: Bool
    public var queries: [String]
    public var curiosity: String
    public var sourceHints: [String]
    public var fastPath: Bool

    public init(shouldSearch: Bool, queries: [String] = [], curiosity: String = "", sourceHints: [String] = [], fastPath: Bool = false) {
        self.shouldSearch = shouldSearch
        self.queries = Array(queries.prefix(2))
        self.curiosity = curiosity
        self.sourceHints = Array(sourceHints.prefix(2))
        self.fastPath = fastPath
    }
}

public struct SearchPayload: Codable, Sendable, Equatable {
    public var query: String
    public var summary: String
    public var rawSummary: String
    public var resultCount: Int
    public var source: String
    public var mode: String

    public init(query: String, summary: String, rawSummary: String = "", resultCount: Int, source: String, mode: String) {
        self.query = query
        self.summary = summary
        self.rawSummary = rawSummary
        self.resultCount = resultCount
        self.source = source
        self.mode = mode
    }
}

public struct EnrichmentMetadata: Codable, Sendable {
    public var skipped: Bool?
    public var reason: String?
    public var error: String?
    public var searched: Bool?
    public var queries: [String]?
    public var curiosity: String?
    public var resultCounts: [Int]?
    public var sources: [String]?
    public var fastPath: Bool?
    public var digested: Bool?
    public var intent: SearchIntent?

    public init(skipped: Bool? = nil, reason: String? = nil, error: String? = nil, searched: Bool? = nil, queries: [String]? = nil, curiosity: String? = nil, resultCounts: [Int]? = nil, sources: [String]? = nil, fastPath: Bool? = nil, digested: Bool? = nil, intent: SearchIntent? = nil) {
        self.skipped = skipped; self.reason = reason; self.error = error; self.searched = searched
        self.queries = queries; self.curiosity = curiosity; self.resultCounts = resultCounts
        self.sources = sources; self.fastPath = fastPath; self.digested = digested; self.intent = intent
    }
}

public struct EnrichmentResult: Codable, Sendable {
    public var contextBlock: String
    public var meta: EnrichmentMetadata
    public init(contextBlock: String, meta: EnrichmentMetadata) { self.contextBlock = contextBlock; self.meta = meta }
}

public struct XHSStatus: Codable, Sendable {
    public var configured: Bool
    public var baseURL: String
    public var hasAuthToken: Bool
    public var reachable: Bool
    public var loggedIn: Bool
    public var username: String
    public var error: String
}

public struct ImageCandidate: Codable, Sendable, Equatable {
    public var imageUrl: String
    public var title: String
    public var feedId: String
    public var xsecToken: String
    public var noteUrl: String
    public var noteType: String
    public var source: String
}

public struct ImageSearchResult: Codable, Sendable {
    public var status: String
    public var message: String?
    public var filename: String?
    public var prompt: String?
    public var title: String?
    public var source: String?
    public var noteUrl: String?
    public var noteType: String?

    public static func failure(_ message: String) -> ImageSearchResult {
        ImageSearchResult(status: "error", message: message)
    }
}

public enum ResearchError: Error, LocalizedError {
    case invalidURL(String)
    case httpStatus(Int, String)
    case responseTooLarge
    case invalidResponse(String)
    case storage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value): return "Invalid URL: \(value)"
        case .httpStatus(let code, let body): return "HTTP \(code): \(String(body.prefix(240)))"
        case .responseTooLarge: return "Response exceeded the configured size limit"
        case .invalidResponse(let message): return message
        case .storage(let message): return message
        }
    }
}
