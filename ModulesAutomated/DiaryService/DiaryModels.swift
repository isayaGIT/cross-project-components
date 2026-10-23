import Foundation

/// A JSON value that preserves the range of values accepted by the Python diary service.
public indirect enum DiaryJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([DiaryJSONValue])
    case object([String: DiaryJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DiaryJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: DiaryJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Mirrors Python's truthiness for JSON-representable values.
    public var isTruthy: Bool {
        switch self {
        case .null:
            return false
        case .bool(let value):
            return value
        case .integer(let value):
            return value != 0
        case .number(let value):
            return value != 0 && !value.isNaN
        case .string(let value):
            return !value.isEmpty
        case .array(let value):
            return !value.isEmpty
        case .object(let value):
            return !value.isEmpty
        }
    }
}

public struct DiaryUserSection: Codable, Sendable {
    public var content: String
    public var sticker: DiaryJSONValue
    public var updatedAt: DiaryJSONValue
    public var extra: [String: DiaryJSONValue]

    public init(
        content: String = "",
        sticker: DiaryJSONValue = .null,
        updatedAt: DiaryJSONValue = .null,
        extra: [String: DiaryJSONValue] = [:]
    ) {
        self.content = content
        self.sticker = sticker
        self.updatedAt = updatedAt
        self.extra = extra
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: DiaryJSONValue].self)
        content = values["content"]?.stringValue ?? ""
        sticker = values["sticker"] ?? .null
        updatedAt = values["updatedAt"] ?? .null
        extra = values.filter { !["content", "sticker", "updatedAt"].contains($0.key) }
    }

    public func encode(to encoder: Encoder) throws {
        var values = extra
        values["content"] = .string(content)
        values["sticker"] = sticker
        values["updatedAt"] = updatedAt
        try values.encode(to: encoder)
    }
}

public struct DiaryAISection: Codable, Sendable {
    public var toUser: String
    public var privateContent: String
    public var sticker: DiaryJSONValue
    public var updatedAt: DiaryJSONValue
    public var scheduledAt: DiaryJSONValue
    public var extra: [String: DiaryJSONValue]

    public init(
        toUser: String = "",
        privateContent: String = "",
        sticker: DiaryJSONValue = .null,
        updatedAt: DiaryJSONValue = .null,
        scheduledAt: DiaryJSONValue = .null,
        extra: [String: DiaryJSONValue] = [:]
    ) {
        self.toUser = toUser
        self.privateContent = privateContent
        self.sticker = sticker
        self.updatedAt = updatedAt
        self.scheduledAt = scheduledAt
        self.extra = extra
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: DiaryJSONValue].self)
        toUser = values["toUser"]?.stringValue ?? ""
        privateContent = values["private"]?.stringValue ?? ""
        sticker = values["sticker"] ?? .null
        updatedAt = values["updatedAt"] ?? .null
        scheduledAt = values["scheduledAt"] ?? .null
        extra = values.filter { !["toUser", "private", "sticker", "updatedAt", "scheduledAt"].contains($0.key) }
    }

    public func encode(to encoder: Encoder) throws {
        var values = extra
        values["toUser"] = .string(toUser)
        values["private"] = .string(privateContent)
        values["sticker"] = sticker
        values["updatedAt"] = updatedAt
        values["scheduledAt"] = scheduledAt
        try values.encode(to: encoder)
    }
}

public struct DiaryEntry: Codable, Sendable {
    public var date: String
    public var user: DiaryUserSection
    public var ai: DiaryAISection
    public var tags: DiaryJSONValue
    public var extra: [String: DiaryJSONValue]

    public init(
        date: String,
        user: DiaryUserSection = DiaryUserSection(),
        ai: DiaryAISection = DiaryAISection(),
        tags: DiaryJSONValue = .array([]),
        extra: [String: DiaryJSONValue] = [:]
    ) {
        self.date = date
        self.user = user
        self.ai = ai
        self.tags = tags
        self.extra = extra
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: DiaryJSONValue].self)
        date = values["date"]?.stringValue ?? ""
        user = Self.decodeSection(DiaryUserSection.self, from: values["user"])
        ai = Self.decodeSection(DiaryAISection.self, from: values["ai"])
        tags = values["tags"] ?? .array([])
        extra = values.filter { !["date", "user", "ai", "tags"].contains($0.key) }
    }

    public func encode(to encoder: Encoder) throws {
        var values = extra
        values["date"] = .string(date)
        values["user"] = .object(Self.encodeSection(user))
        values["ai"] = .object(Self.encodeSection(ai))
        values["tags"] = tags
        try values.encode(to: encoder)
    }

    private static func decodeSection<T: Decodable>(_ type: T.Type, from value: DiaryJSONValue?) -> T {
        guard let value, let data = try? JSONEncoder().encode(value), let decoded = try? JSONDecoder().decode(type, from: data) else {
            if type == DiaryUserSection.self, let fallback = DiaryUserSection() as? T { return fallback }
            if type == DiaryAISection.self, let fallback = DiaryAISection() as? T { return fallback }
            preconditionFailure("Unsupported diary section type")
        }
        return decoded
    }

    private static func encodeSection<T: Encodable>(_ section: T) -> [String: DiaryJSONValue] {
        guard let data = try? JSONEncoder().encode(section),
              let value = try? JSONDecoder().decode([String: DiaryJSONValue].self, from: data) else {
            return [:]
        }
        return value
    }
}

public struct DiaryDaySummary: Codable, Sendable {
    public var date: String
    public var userSticker: DiaryJSONValue
    public var aiSticker: DiaryJSONValue
    public var hasUser: Bool
    public var hasAi: Bool
    public var userPreview: String
    public var userContent: String?
    public var aiToUser: String?
    public var aiPrivate: String?

    public init(
        date: String,
        userSticker: DiaryJSONValue = .null,
        aiSticker: DiaryJSONValue = .null,
        hasUser: Bool = false,
        hasAi: Bool = false,
        userPreview: String = "",
        userContent: String? = nil,
        aiToUser: String? = nil,
        aiPrivate: String? = nil
    ) {
        self.date = date
        self.userSticker = userSticker
        self.aiSticker = aiSticker
        self.hasUser = hasUser
        self.hasAi = hasAi
        self.userPreview = userPreview
        self.userContent = userContent
        self.aiToUser = aiToUser
        self.aiPrivate = aiPrivate
    }

    private enum CodingKeys: String, CodingKey {
        case date, userSticker, aiSticker, hasUser, hasAi, userPreview, userContent, aiToUser, aiPrivate
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decodeIfPresent(String.self, forKey: .date) ?? ""
        userSticker = try values.decodeIfPresent(DiaryJSONValue.self, forKey: .userSticker) ?? .null
        aiSticker = try values.decodeIfPresent(DiaryJSONValue.self, forKey: .aiSticker) ?? .null
        hasUser = try values.decodeIfPresent(Bool.self, forKey: .hasUser) ?? false
        hasAi = try values.decodeIfPresent(Bool.self, forKey: .hasAi) ?? false
        userPreview = try values.decodeIfPresent(String.self, forKey: .userPreview) ?? ""
        userContent = try values.decodeIfPresent(String.self, forKey: .userContent)
        aiToUser = try values.decodeIfPresent(String.self, forKey: .aiToUser)
        aiPrivate = try values.decodeIfPresent(String.self, forKey: .aiPrivate)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(date, forKey: .date)
        try values.encode(userSticker, forKey: .userSticker)
        try values.encode(aiSticker, forKey: .aiSticker)
        try values.encode(hasUser, forKey: .hasUser)
        try values.encode(hasAi, forKey: .hasAi)
        try values.encode(userPreview, forKey: .userPreview)
        try values.encodeIfPresent(userContent, forKey: .userContent)
        try values.encodeIfPresent(aiToUser, forKey: .aiToUser)
        try values.encodeIfPresent(aiPrivate, forKey: .aiPrivate)
    }
}

public struct DiaryReflectionResult: Sendable {
    public var toUser: String
    public var privateContent: String
    public var sticker: String?

    public init(toUser: String, privateContent: String, sticker: String? = nil) {
        self.toUser = toUser
        self.privateContent = privateContent
        self.sticker = sticker
    }
}

public struct DiaryMonthCalendar: Sendable {
    public var year: Int
    public var month: Int
    public var days: [String: DiaryDaySummary]

    public init(year: Int, month: Int, days: [String: DiaryDaySummary]) {
        self.year = year
        self.month = month
        self.days = days
    }
}
