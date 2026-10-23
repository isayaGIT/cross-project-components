import Foundation

/// Filesystem-backed migration of cloud/services/kaomoji_store.py.
/// Actor isolation serializes operations performed through the same instance.
public actor KaomojiStoreService {
    public struct Configuration: Sendable {
        public let savesRoot: URL
        public let legacyCustomFileURL: URL?

        public init(savesRoot: URL, legacyCustomFileURL: URL? = nil) {
            self.savesRoot = savesRoot
            self.legacyCustomFileURL = legacyCustomFileURL
        }
    }

    private let configuration: Configuration
    private let fileManager: FileManager

    public init(configuration: Configuration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    /// Returns and creates <savesRoot>/Stickers/kaomoji when needed.
    public func directoryURL() throws -> URL {
        let directory = configuration.savesRoot
            .appendingPathComponent("Stickers", isDirectory: true)
            .appendingPathComponent("kaomoji", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return directory
        } catch {
            throw KaomojiStoreError.cannotCreateDirectory(directory, error.localizedDescription)
        }
    }

    /// Returns the primary store path, creating its parent directory.
    public func storeURL() throws -> URL {
        try directoryURL().appendingPathComponent("store.json", isDirectory: false)
    }

    /// Loads the primary store or falls back to legacy categories and defaults.
    /// Read and migration errors are suppressed, matching the Python source behavior.
    public func load() -> KaomojiStore {
        do {
            let primaryURL = try storeURL()
            if fileManager.fileExists(atPath: primaryURL.path),
               let data = try? Data(contentsOf: primaryURL),
               let json = try? JSONSerialization.jsonObject(with: data),
               json is [String: Any] {
                return KaomojiStoreNormalizer.normalize(json)
            }
        } catch {
            // A failed primary read follows the source's migration/default path.
        }

        guard let legacyURL = configuration.legacyCustomFileURL,
              fileManager.fileExists(atPath: legacyURL.path) else {
            return .empty
        }

        // An existing legacy file triggers migration even when it is malformed.
        var legacyCategories: Any = [Any]()
        if let data = try? Data(contentsOf: legacyURL),
           let json = try? JSONSerialization.jsonObject(with: data) {
            if let object = json as? [String: Any],
               let categories = object["categories"] as? [Any] {
                legacyCategories = categories
            } else if let array = json as? [Any] {
                legacyCategories = array
            }
        }

        let migratedStore = KaomojiStoreNormalizer.normalize(["categories": legacyCategories])
        do {
            _ = try save(migratedStore)
            // Path.with_suffix(".json.migrated") for the usual legacy .json file.
            let migratedURL = legacyURL.deletingPathExtension()
                .appendingPathExtension("json.migrated")
            do {
                if fileManager.fileExists(atPath: migratedURL.path) {
                    try fileManager.removeItem(at: migratedURL)
                }
                try fileManager.moveItem(at: legacyURL, to: migratedURL)
            } catch {
                // Renaming is best-effort; retain the original if it fails.
            }
        } catch {
            // The source returns the normalized legacy/default data even if saving fails.
        }
        return migratedStore
    }

    /// Cleans and persists a typed store, surfacing save failures to the caller.
    @discardableResult
    public func save(_ store: KaomojiStore) throws -> KaomojiStore {
        let normalized = store.normalized()
        let destination = try storeURL()
        let object: [String: Any] = [
            "categories": normalized.categories.map { ["name": $0.name, "items": $0.items] },
            "favorites": normalized.favorites,
            "recent": normalized.recent,
            "activePack": normalized.activePack
        ]

        let data: Data
        do {
            data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )
        } catch {
            throw KaomojiStoreError.cannotEncode(error.localizedDescription)
        }

        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw KaomojiStoreError.cannotWrite(destination, error.localizedDescription)
        }
        return normalized
    }

    /// Decodes, normalizes, and persists an arbitrary JSON document from Sendable bytes.
    @discardableResult
    public func saveJSONData(_ data: Data) throws -> KaomojiStore {
        let normalized = try KaomojiStore.normalize(jsonData: data)
        return try save(normalized)
    }
}
