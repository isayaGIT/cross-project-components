import Foundation
import CoreFoundation

/// Normalized, JSON-compatible user data for the kaomoji store.
public struct KaomojiStore: Codable, Equatable, Sendable {
    public struct Category: Codable, Equatable, Sendable {
        public var name: String
        public var items: [String]

        public init(name: String, items: [String]) {
            self.name = name
            self.items = items
        }
    }

    public var categories: [Category]
    public var favorites: [String]
    public var recent: [String]
    public var activePack: String

    public init(
        categories: [Category] = [],
        favorites: [String] = [],
        recent: [String] = [],
        activePack: String = "kaomoji"
    ) {
        self.categories = categories
        self.favorites = favorites
        self.recent = recent
        self.activePack = activePack
    }

    public static let empty = KaomojiStore()

    /// Normalizes typed values using the same limits as the Python clean_store function.
    public func normalized() -> KaomojiStore {
        KaomojiStoreNormalizer.normalize(self)
    }

    /// Decodes arbitrary JSON bytes and normalizes the root object.
    /// A non-object JSON root produces the empty/default store, matching clean_store.
    public static func normalize(jsonData: Data) throws -> KaomojiStore {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(
                with: jsonData,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw KaomojiStoreError.invalidJSON(error.localizedDescription)
        }
        return KaomojiStoreNormalizer.normalize(value)
    }
}

public enum KaomojiStoreError: Error, LocalizedError, Sendable {
    case cannotCreateDirectory(URL, String)
    case cannotWrite(URL, String)
    case cannotEncode(String)
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case let .cannotCreateDirectory(url, message):
            return "Cannot create kaomoji storage directory at \(url.path): \(message)"
        case let .cannotWrite(url, message):
            return "Cannot write kaomoji store at \(url.path): \(message)"
        case let .cannotEncode(message):
            return "Cannot encode kaomoji store: \(message)"
        case let .invalidJSON(message):
            return "Invalid JSON supplied to kaomoji store: \(message)"
        }
    }
}

enum KaomojiStoreNormalizer {
    static func normalize(_ input: Any?) -> KaomojiStore {
        guard let object = input as? [String: Any] else { return .empty }

        let rawPack = object["activePack"]
        let selectedPack = pythonTruthy(rawPack) ? pythonString(rawPack!) : "kaomoji"
        let trimmedPack = selectedPack.trimmingCharacters(in: .whitespacesAndNewlines)
        let pack = scalarPrefix(trimmedPack.isEmpty ? "kaomoji" : trimmedPack, limit: 64)

        return KaomojiStore(
            categories: cleanCategories(object["categories"]),
            favorites: cleanStringList(object["favorites"], limit: 80),
            recent: cleanStringList(object["recent"], limit: 48),
            activePack: pack.isEmpty ? "kaomoji" : pack
        )
    }

    static func normalize(_ input: KaomojiStore) -> KaomojiStore {
        let categories = input.categories.prefix(40).compactMap { category -> KaomojiStore.Category? in
            let name = scalarPrefix(
                category.name.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 32
            )
            guard !name.isEmpty else { return nil }
            return KaomojiStore.Category(
                name: name,
                items: cleanStringList(category.items, limit: 80)
            )
        }

        let trimmedPack = input.activePack.trimmingCharacters(in: .whitespacesAndNewlines)
        let pack = scalarPrefix(trimmedPack.isEmpty ? "kaomoji" : trimmedPack, limit: 64)
        return KaomojiStore(
            categories: Array(categories),
            favorites: cleanStringList(input.favorites, limit: 80),
            recent: cleanStringList(input.recent, limit: 48),
            activePack: pack.isEmpty ? "kaomoji" : pack
        )
    }

    private static func cleanCategories(_ raw: Any?) -> [KaomojiStore.Category] {
        guard let list = raw as? [Any] else { return [] }
        return list.prefix(40).compactMap { element in
            guard let object = element as? [String: Any] else { return nil }
            let rawName = object["name"] ?? ""
            let name = scalarPrefix(
                pythonString(rawName).trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 32
            )
            guard !name.isEmpty else { return nil }

            // The source uses c.get("items") or [], so falsey JSON values become [].
            let rawItems = object["items"]
            let itemsInput: Any = pythonTruthy(rawItems) ? rawItems! : [Any]()
            return KaomojiStore.Category(
                name: name,
                items: cleanStringList(itemsInput, limit: 80)
            )
        }
    }

    private static func cleanStringList(_ raw: Any?, limit: Int, itemMax: Int = 64) -> [String] {
        guard let list = raw as? [Any] else { return [] }
        var result: [String] = []
        var seen = Set<String>()

        // The Python source slices the raw list before converting/filtering its values.
        for value in list.prefix(limit) {
            let trimmed = pythonString(value).trimmingCharacters(in: .whitespacesAndNewlines)
            let item = scalarPrefix(trimmed, limit: itemMax)
            if !item.isEmpty && seen.insert(item).inserted {
                result.append(item)
            }
        }
        return result
    }

    private static func cleanStringList(_ raw: [String], limit: Int, itemMax: Int = 64) -> [String] {
        cleanStringList(raw.map { $0 as Any }, limit: limit, itemMax: itemMax)
    }

    private static func pythonTruthy(_ value: Any?) -> Bool {
        guard let value, !(value is NSNull) else { return false }
        if let string = value as? String { return !string.isEmpty }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
            return number.doubleValue != 0
        }
        if let array = value as? [Any] { return !array.isEmpty }
        if let dictionary = value as? [String: Any] { return !dictionary.isEmpty }
        return true
    }

    /// Approximation of Python str() for values decoded from JSON.
    private static func pythonString(_ value: Any) -> String {
        if value is NSNull { return "None" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : "False"
            }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + array.map(pythonRepr).joined(separator: ", ") + "]"
        }
        if let dictionary = value as? [String: Any] {
            let members = dictionary.keys.sorted().map { key in
                "\(pythonRepr(key)): \(pythonRepr(dictionary[key] ?? NSNull()))"
            }
            return "{" + members.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }

    private static func pythonRepr(_ value: Any) -> String {
        if value is NSNull { return "None" }
        if let string = value as? String {
            let quote = string.contains("'") && !string.contains("\"") ? "\"" : "'"
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: quote, with: "\\" + quote)
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return quote + escaped + quote
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : "False"
            }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + array.map(pythonRepr).joined(separator: ", ") + "]"
        }
        if let dictionary = value as? [String: Any] {
            let members = dictionary.keys.sorted().map { key in
                "\(pythonRepr(key)): \(pythonRepr(dictionary[key] ?? NSNull()))"
            }
            return "{" + members.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }

    /// Python string slicing counts Unicode code points; Swift String.prefix counts grapheme clusters.
    private static func scalarPrefix(_ value: String, limit: Int) -> String {
        guard limit > 0 else { return "" }
        return String(String.UnicodeScalarView(value.unicodeScalars.prefix(limit)))
    }
}
