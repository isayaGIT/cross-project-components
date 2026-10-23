import Foundation

/// One normalized entry from assets/Stickers/descriptions.json.
public struct StickerCatalogEntry: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let file: String
    public let collection: String
    public let description: String
    public let url: String

    public init(
        id: String,
        path: String,
        file: String,
        collection: String,
        description: String,
        url: String
    ) {
        self.id = id
        self.path = path
        self.file = file
        self.collection = collection
        self.description = description
        self.url = url
    }
}

/// Configuration for locating and interpreting the sticker catalog.
public struct StickerCatalogConfiguration: Sendable {
    /// Directory containing descriptions.json, normally assets/Stickers.
    public let stickersRoot: URL

    /// Public URL prefix used by the Python service.
    public let assetURLPrefix: String

    public init(
        stickersRoot: URL,
        assetURLPrefix: String = "/assets/Stickers/"
    ) {
        self.stickersRoot = stickersRoot.standardizedFileURL
        self.assetURLPrefix = assetURLPrefix.hasSuffix("/")
            ? assetURLPrefix
            : assetURLPrefix + "/"
    }

    /// Builds a configuration from a project assets directory.
    /// The supplied URL should identify the directory named Stickers, not its parent.
    public static func fromAssetsRoot(
        _ assetsRoot: URL,
        assetURLPrefix: String = "/assets/Stickers/"
    ) -> StickerCatalogConfiguration {
        StickerCatalogConfiguration(
            stickersRoot: assetsRoot.appendingPathComponent("Stickers", isDirectory: true),
            assetURLPrefix: assetURLPrefix
        )
    }
}

public enum StickerCatalogError: Error, LocalizedError, Sendable {
    case fileReadFailed(path: String, reason: String)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case let .fileReadFailed(path, reason):
            return "Unable to read sticker catalog at \(path): \(reason)"
        case .encodingFailed:
            return "Unable to encode sticker catalog data."
        }
    }
}

/// Filesystem boundary kept injectable for alternate storage and integration environments.
public protocol StickerCatalogFileAccess: Sendable {
    func readData(from url: URL) throws -> Data
    func fileExists(at url: URL) -> Bool
}

public struct LocalStickerCatalogFileAccess: StickerCatalogFileAccess {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func readData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
