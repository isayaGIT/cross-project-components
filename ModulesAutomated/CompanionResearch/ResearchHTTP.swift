import Foundation

public struct HTTPPayload: Sendable {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]
    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data; self.statusCode = statusCode; self.headers = headers
    }
}

public protocol ResearchHTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> HTTPPayload
}

public struct URLSessionResearchTransport: ResearchHTTPTransport {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest, maximumBytes: Int = 8_000_000) async throws -> HTTPPayload {
        let (data, response) = try await session.data(for: request)
        guard data.count <= maximumBytes else { throw ResearchError.responseTooLarge }
        guard let http = response as? HTTPURLResponse else {
            throw ResearchError.invalidResponse("Expected an HTTP response")
        }
        let headers = Dictionary(uniqueKeysWithValues: http.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let k = key as? String else { return nil }
            return (k, String(describing: value))
        })
        guard (200..<300).contains(http.statusCode) else {
            throw ResearchError.httpStatus(http.statusCode, String(data: data.prefix(240), encoding: .utf8) ?? "")
        }
        return HTTPPayload(data: data, statusCode: http.statusCode, headers: headers)
    }
}

public struct ResearchConfiguration: Sendable {
    public var serperAPIKey: String
    public var xhsBaseURL: URL
    public var xhsAuthToken: String
    public var imageSearchDisabled: Bool
    public var requestTimeout: TimeInterval
    public var maximumResponseBytes: Int
    public var maximumImageBytes: Int
    public var userAgent: String

    public init(serperAPIKey: String = "", xhsBaseURL: URL? = nil, xhsAuthToken: String = "", imageSearchDisabled: Bool = false, requestTimeout: TimeInterval = 15, maximumResponseBytes: Int = 8_000_000, maximumImageBytes: Int = 12_000_000, userAgent: String = "Mozilla/5.0 (compatible; CompanionResearch/1.0)") {
        self.serperAPIKey = serperAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = xhsBaseURL ?? URL(string: "http://127.0.0.1:18060")!
        self.xhsBaseURL = candidate.scheme == "https" || candidate.scheme == "http" ? candidate : URL(string: "http://127.0.0.1:18060")!
        self.xhsAuthToken = xhsAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.imageSearchDisabled = imageSearchDisabled
        self.requestTimeout = requestTimeout
        self.maximumResponseBytes = max(1024, maximumResponseBytes)
        self.maximumImageBytes = max(1024, maximumImageBytes)
        self.userAgent = userAgent
    }

    public static func environment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> ResearchConfiguration {
        let rawBase = (environment["XHS_MCP_BASE_URL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = URL(string: rawBase)
        let validBase = parsed.flatMap { ($0.scheme == "https" || $0.scheme == "http") && $0.host != nil ? $0 : nil }
        let disabled = ["1", "true", "yes", "on"].contains((environment["IMAGE_SEARCH_DISABLED"] ?? "").lowercased())
        return ResearchConfiguration(serperAPIKey: environment["SERPER_API_KEY"] ?? "", xhsBaseURL: validBase, xhsAuthToken: environment["XHS_MCP_AUTH_TOKEN"] ?? "", imageSearchDisabled: disabled)
    }
}

func jsonObject(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ResearchError.invalidResponse("Expected a JSON object")
    }
    return object
}

func stringValue(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "" }
    return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
}

func urlEncoded(_ values: [String: String]) -> String {
    var components = URLComponents()
    components.queryItems = values.keys.sorted().map { URLQueryItem(name: $0, value: values[$0]) }
    return components.percentEncodedQuery ?? ""
}

func makeRequest(url: URL, method: String = "GET", body: Data? = nil, headers: [String: String] = [:], timeout: TimeInterval) -> URLRequest {
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = method
    request.httpBody = body
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    return request
}
