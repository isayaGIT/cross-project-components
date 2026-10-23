import Foundation

/// Native Swift implementation of the backend sticker-catalog service.
///
/// The actor serializes catalog reads within one service instance. Catalog contents are loaded
/// on demand; no implicit cache is maintained, so edits to descriptions.json become visible on
/// the next call.
public actor StickerCatalogService {
    private let configuration: StickerCatalogConfiguration
    private let fileAccess: any StickerCatalogFileAccess

    public init(
        configuration: StickerCatalogConfiguration,
        fileAccess: any StickerCatalogFileAccess = LocalStickerCatalogFileAccess()
    ) {
        self.configuration = configuration
        self.fileAccess = fileAccess
    }

    public init(
        stickersRoot: URL,
        fileAccess: any StickerCatalogFileAccess = LocalStickerCatalogFileAccess()
    ) {
        self.init(
            configuration: StickerCatalogConfiguration(stickersRoot: stickersRoot),
            fileAccess: fileAccess
        )
    }

    public func loadCatalog() -> [StickerCatalogEntry] {
        let descriptionURL = configuration.stickersRoot.appendingPathComponent("descriptions.json")
        guard fileAccess.fileExists(at: descriptionURL) else { return [] }
        guard let data = try? fileAccess.readData(from: descriptionURL),
              let root = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let dictionary = root as? [String: Any] else {
            return []
        }

        var entries: [StickerCatalogEntry] = []
        entries.reserveCapacity(dictionary.count)

        // JSONSerialization dictionaries do not promise source insertion order. The final output
        // is explicitly sorted, matching the Python service's externally visible ordering.
        for (key, rawMetadata) in dictionary {
            guard let metadata = rawMetadata as? [String: Any],
                  let safePath = StickerCatalogPath.safeRelativePath(key) else {
                continue
            }

            let file = Self.pythonTruthyString(metadata["file"]) ?? safePath.split(separator: "/").last.map(String.init) ?? safePath
            let collection = Self.pythonTruthyString(metadata["collection"]) ?? ""
            let description = Self.pythonTruthyString(metadata["description"]) ?? ""

            entries.append(
                StickerCatalogEntry(
                    id: safePath,
                    path: safePath,
                    file: file,
                    collection: collection,
                    description: description,
                    url: configuration.assetURLPrefix + safePath
                )
            )
        }

        return entries.sorted {
            if $0.collection != $1.collection { return $0.collection < $1.collection }
            return $0.file < $1.file
        }
    }

    /// Returns the source-compatible prompt block. A negative maxItems follows Python slicing:
    /// all but the final abs(maxItems) entries are included.
    public nonisolated static func promptBlock(
        catalog: [StickerCatalogEntry],
        maxItems: Int = 40
    ) -> String {
        let count: Int
        if maxItems >= 0 {
            count = min(maxItems, catalog.count)
        } else {
            count = max(0, catalog.count + maxItems)
        }
        return catalog.prefix(count).map { "- \($0.id)：\($0.description)" }.joined(separator: "\n")
    }

    /// Instance convenience API that loads the current catalog and formats its prompt block.
    public func promptBlock(maxItems: Int = 40) -> String {
        Self.promptBlock(catalog: loadCatalog(), maxItems: maxItems)
    }

    /// Resolves a supplied sticker ID against a catalog, returning nil for invalid or unknown IDs.
    /// Exact identifier matches take precedence over suffix and filename matches.
    public nonisolated static func normalizeStickerID(
        _ stickerID: String?,
        catalog: [StickerCatalogEntry]
    ) -> String? {
        guard let stickerID, !stickerID.isEmpty,
              let normalized = StickerCatalogPath.safeRelativePath(stickerID) else {
            return nil
        }

        if catalog.contains(where: { $0.id == normalized }) {
            return normalized
        }
        for entry in catalog {
            if entry.id.hasSuffix("/" + normalized) || entry.file == normalized {
                return entry.id
            }
        }
        return nil
    }

    /// Resolves an identifier against the currently loaded catalog.
    public func normalizeStickerID(_ stickerID: String?) -> String? {
        Self.normalizeStickerID(stickerID, catalog: loadCatalog())
    }

    /// Encodes a catalog as JSON for an integration that needs to expose the normalized contract.
    public nonisolated static func encodeCatalog(_ catalog: [StickerCatalogEntry], prettyPrinted: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] }
        do {
            return try encoder.encode(catalog)
        } catch {
            throw StickerCatalogError.encodingFailed
        }
    }

    private static func pythonTruthyString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string.isEmpty ? nil : string }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : nil
            }
            return number.stringValue == "0" ? nil : number.stringValue
        }
        if let array = value as? [Any] { return array.isEmpty ? nil : String(describing: array) }
        if let object = value as? [String: Any] { return object.isEmpty ? nil : String(describing: object) }
        return nil
    }
}

import CoreFoundation
