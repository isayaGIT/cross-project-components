import Foundation

/// Dependency-injected implementation of cloud/llm/routing.py.
/// The host owns profile loading, credential lookup, and application-specific paths.
public final class LLMRouting: @unchecked Sendable {
    public struct ResolvedConfiguration: Codable, Equatable, Sendable {
        public let apiUrl: String
        public let model: String
        public let apiKey: String

        public init(apiUrl: String, model: String, apiKey: String) {
            self.apiUrl = apiUrl
            self.model = model
            self.apiKey = apiKey
        }
    }

    public struct Profile: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let apiUrl: String
        public let model: String
        public let apiKey: String?
        public let additionalFields: [String: JSONValue]

        public init(id: String, name: String = "", apiUrl: String = "", model: String = "", apiKey: String? = nil, additionalFields: [String: JSONValue] = [:]) {
            self.id = id
            self.name = name
            self.apiUrl = apiUrl
            self.model = model
            self.apiKey = apiKey
            self.additionalFields = additionalFields
        }

        private enum CodingKeys: String, CodingKey { case id, name, apiUrl, model, apiKey }
        private struct DynamicCodingKey: CodingKey {
            let stringValue: String
            let intValue: Int? = nil
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
            name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
            apiUrl = try values.decodeIfPresent(String.self, forKey: .apiUrl) ?? ""
            model = try values.decodeIfPresent(String.self, forKey: .model) ?? ""
            apiKey = try values.decodeIfPresent(String.self, forKey: .apiKey)
            let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
            var extras: [String: JSONValue] = [:]
            for key in dynamic.allKeys where !["id", "name", "apiUrl", "model", "apiKey"].contains(key.stringValue) {
                extras[key.stringValue] = try dynamic.decode(JSONValue.self, forKey: key)
            }
            additionalFields = extras
        }

        public func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(id, forKey: .id)
            try values.encode(name, forKey: .name)
            try values.encode(apiUrl, forKey: .apiUrl)
            try values.encode(model, forKey: .model)
            try values.encodeIfPresent(apiKey, forKey: .apiKey)
            var dynamic = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalFields {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try dynamic.encode(value, forKey: codingKey)
            }
        }
    }

    public indirect enum JSONValue: Codable, Equatable, Sendable {
        case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

        public init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() { self = .null }
            else if let v = try? value.decode(String.self) { self = .string(v) }
            else if let v = try? value.decode(Bool.self) { self = .bool(v) }
            else if let v = try? value.decode(Double.self) { self = .number(v) }
            else if let v = try? value.decode([String: JSONValue].self) { self = .object(v) }
            else if let v = try? value.decode([JSONValue].self) { self = .array(v) }
            else { throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unsupported JSON value") }
        }

        public func encode(to encoder: Encoder) throws {
            var value = encoder.singleValueContainer()
            switch self {
            case .string(let v): try value.encode(v)
            case .number(let v): try value.encode(v)
            case .bool(let v): try value.encode(v)
            case .object(let v): try value.encode(v)
            case .array(let v): try value.encode(v)
            case .null: try value.encodeNil()
            }
        }

        public var stringValue: String? { if case .string(let value) = self { return value }; return nil }
        public var objectValue: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    }

    public struct Dependencies: Sendable {
        public let llmRoutesURL: URL
        public let providerConfigURL: URL
        public let loadProfiles: @Sendable () -> [Profile]
        public let profileKey: @Sendable (Profile) -> String
        public let loadMomentsConfig: @Sendable () -> [String: JSONValue]
        public let loadTTSAnnotationConfig: @Sendable () -> [String: JSONValue]

        public init(llmRoutesURL: URL, providerConfigURL: URL, loadProfiles: @escaping @Sendable () -> [Profile], profileKey: @escaping @Sendable (Profile) -> String, loadMomentsConfig: @escaping @Sendable () -> [String: JSONValue] = { [:] }, loadTTSAnnotationConfig: @escaping @Sendable () -> [String: JSONValue] = { [:] }) {
            self.llmRoutesURL = llmRoutesURL
            self.providerConfigURL = providerConfigURL
            self.loadProfiles = loadProfiles
            self.profileKey = profileKey
            self.loadMomentsConfig = loadMomentsConfig
            self.loadTTSAnnotationConfig = loadTTSAnnotationConfig
        }
    }

    public enum RoutingError: Error, LocalizedError, Sendable {
        case notConfigured
        case configurationReadFailed(URL, String)
        case invalidConfiguration(URL, String)
        public var errorDescription: String? {
            switch self {
            case .notConfigured: return "LLM routing dependencies have not been configured."
            case .configurationReadFailed(let url, let message): return "Unable to read routing configuration at \(url.path): \(message)"
            case .invalidConfiguration(let url, let message): return "Invalid routing configuration at \(url.path): \(message)"
            }
        }
    }

    private struct RouteTask: Decodable {
        let hasUISlot: Bool?
        let provider: String?
        let model: String?
        enum CodingKeys: String, CodingKey { case hasUISlot = "has_ui_slot", provider, model }
    }
    private struct RoutesDocument: Decodable { let tasks: [String: RouteTask]? }
    private struct ChatConfiguration: Decodable { let profileId: String?; let provider: String?; let model: String? }
    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private let dependencies: Dependencies
    private let fileManager: FileManager
    private let lock = NSRecursiveLock()
    private static let momentsSlotFields: [String: (profileID: String, model: String)] = [
        "moments": ("momentsProfileId", "momentsModel"),
        "comments": ("commentsProfileId", "commentsModel"),
        "vision": ("visionProfileId", "visionModel"),
        "selector": ("selectorProfileId", "selectorModel"),
        "private": ("privateProfileId", "privateModel")
    ]

    public init(dependencies: Dependencies, fileManager: FileManager = .default) {
        self.dependencies = dependencies
        self.fileManager = fileManager
    }

    public func resolve(_ taskKey: String) -> ResolvedConfiguration {
        lock.lock(); defer { lock.unlock() }
        if let task = loadRoutes()[taskKey], task.hasUISlot == false {
            let provider = trimmed(task.provider)
            if !provider.isEmpty, provider != "ui", let selected = profile(id: provider) ?? profile(name: provider) {
                return resolved(profile: selected, modelOverride: trimmed(task.model))
            }
            return resolveChatSlot()
        }
        if taskKey == "ttsExtract" { return resolveTTSSlot(sectionNames: ["ttsExtract", "extract"]) }
        if taskKey == "ttsAnnotate" { return resolveTTSSlot(sectionNames: ["ttsAnnotate", "annotate"]) }
        if Self.momentsSlotFields[taskKey] != nil { return resolveMomentsSlot(taskKey) }
        return resolveChatSlot()
    }

    public static func keyProblem(_ apiKey: String?) -> String {
        guard let apiKey, !apiKey.isEmpty else { return "密钥未解析：检查槽位 provider 配置与 .local/provider_keys.json" }
        if apiKey.contains("****") { return "拿到的是打码展示值而非真实密钥（不应发往上游）" }
        return ""
    }
    public func keyProblem(_ apiKey: String?) -> String { Self.keyProblem(apiKey) }

    private func loadRoutes() -> [String: RouteTask] {
        guard fileManager.fileExists(atPath: dependencies.llmRoutesURL.path), let data = try? Data(contentsOf: dependencies.llmRoutesURL), let doc = try? JSONDecoder().decode(RoutesDocument.self, from: data) else { return [:] }
        return doc.tasks ?? [:]
    }

    private func resolveChatSlot() -> ResolvedConfiguration {
        var configuration = ChatConfiguration(profileId: nil, provider: nil, model: nil)
        if fileManager.fileExists(atPath: dependencies.providerConfigURL.path), let data = try? Data(contentsOf: dependencies.providerConfigURL), let value = try? JSONDecoder().decode(ChatConfiguration.self, from: data) { configuration = value }
        let configured = trimmed(configuration.profileId).isEmpty ? (trimmed(configuration.provider).isEmpty ? "deepseek" : trimmed(configuration.provider)) : trimmed(configuration.profileId)
        guard let selected = profile(id: configured) ?? profile(id: "deepseek") else { return ResolvedConfiguration(apiUrl: "", model: trimmed(configuration.model), apiKey: "") }
        return resolved(profile: selected, modelOverride: trimmed(configuration.model))
    }

    private func resolveMomentsSlot(_ slot: String) -> ResolvedConfiguration {
        guard let fields = Self.momentsSlotFields[slot] else { return resolveChatSlot() }
        let config = dependencies.loadMomentsConfig()
        let profileID = trimmed(config[fields.profileID]?.stringValue)
        let model = trimmed(config[fields.model]?.stringValue)
        if !profileID.isEmpty, let selected = profile(id: profileID) { return resolved(profile: selected, modelOverride: model) }
        let chat = resolveChatSlot()
        return ResolvedConfiguration(apiUrl: chat.apiUrl, model: model.isEmpty ? chat.model : model, apiKey: chat.apiKey)
    }

    private func resolveTTSSlot(sectionNames: [String]) -> ResolvedConfiguration {
        let config = dependencies.loadTTSAnnotationConfig()
        var section: [String: JSONValue]?
        for name in sectionNames {
            if let nested = config[name]?.objectValue,
               !trimmed(nested["profileId"]?.stringValue).isEmpty || !trimmed(nested["model"]?.stringValue).isEmpty {
                section = nested
                break
            }
        }
        if section == nil, !trimmed(config["profileId"]?.stringValue).isEmpty || !trimmed(config["model"]?.stringValue).isEmpty { section = config }
        guard let section else { return resolveChatSlot() }
        let profileID = trimmed(section["profileId"]?.stringValue)
        let model = trimmed(section["model"]?.stringValue)
        if !profileID.isEmpty, let selected = profile(id: profileID) { return resolved(profile: selected, modelOverride: model) }
        let chat = resolveChatSlot()
        return ResolvedConfiguration(apiUrl: chat.apiUrl, model: model.isEmpty ? chat.model : model, apiKey: chat.apiKey)
    }

    private func profile(id: String) -> Profile? { guard !id.isEmpty else { return nil }; return dependencies.loadProfiles().first { $0.id == id } }
    private func profile(name: String) -> Profile? { guard !name.isEmpty else { return nil }; return dependencies.loadProfiles().first { $0.name == name } }
    private func resolved(profile: Profile, modelOverride: String) -> ResolvedConfiguration {
        ResolvedConfiguration(apiUrl: profile.apiUrl, model: modelOverride.isEmpty ? profile.model : modelOverride, apiKey: dependencies.profileKey(profile))
    }
    private func trimmed(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
}
