import Foundation
import CryptoKit
import InteractiveAssets

struct AssetManifest: Decodable {
    let schemaVersion: Int
    let appId: String
    let version: String
    let assets: [RemoteAsset]
}

struct RemoteAsset: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let contentType: String
    let size: Int
    let sha256: String
    let versions: [String]
    let downloadUrl: String
}

struct AssetPlacementResponse: Decodable {
    let schemaVersion: Int
    let appId: String
    let version: String
    let slot: String
    let asset: RemoteAsset
}

private struct SlotCatalogResponse: Decodable {
    let schemaVersion: Int
    let appId: String
    let version: String
    let slots: [RemoteSlot]
}

private struct RemoteSlot: Decodable {
    let slot: String
    let assignment: RemoteAssignment?
}

private struct RemoteAssignment: Decodable {
    let assetId: String
    let asset: RemoteAsset
}

enum InteractiveJSONValue: Codable {
    case string(String), integer(Int64), number(Double), bool(Bool), object([String: InteractiveJSONValue]), array([InteractiveJSONValue]), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int64.self) { self = .integer(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: InteractiveJSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([InteractiveJSONValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var objectValue: [String: InteractiveJSONValue]? { if case .object(let value) = self { value } else { nil } }
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
}

struct InteractiveProtocolFile: Decodable {
    let id: String
    let fileName: String
    let mediaType: String
    let byteCount: Int64
    let sha256: String
    let role: String?
}

struct InteractiveProtocolManifest: Decodable {
    let protocolVersion: String
    let contentID: String
    let contentType: String
    let contentVersion: String
    let files: [InteractiveProtocolFile]
}

struct PublishedInteractiveContent: Decodable {
    let protocolVersion: String
    let appId: String
    let version: String
    let id: String
    let type: String
    let contentVersion: String
    let publishedAt: String
    let document: InteractiveJSONValue
}

struct ValidatedInteractiveContent {
    let published: PublishedInteractiveContent
    let manifest: InteractiveProtocolManifest
    let referencedAssetIDs: [String]
}

private struct CachedAsset: Codable {
    let id: String
    let name: String
    let contentType: String
    let sha256: String
    let fileName: String
}

private struct LocalAssetManifest: Codable {
    let schemaVersion: Int
    let appId: String
    let version: String
    let syncedAt: Date
    let assignments: [String: CachedAsset]
}

enum AssetServerError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case checksumMismatch(String)
    case noAssignment(String)
    case invalidInteractiveContent(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an invalid response."
        case .httpStatus(let status): return "AssetServer returned HTTP \(status)."
        case .checksumMismatch(let name): return "SHA-256 verification failed for \(name)."
        case .noAssignment(let slot): return "No asset is assigned to \(slot) for this version."
        case .invalidInteractiveContent(let reason): return "Interactive content validation failed: \(reason)"
        }
    }
}

/// Keeps verified assets as persistent application data, not in the evictable Caches directory.
/// A successful server sync is authoritative: only assets still assigned by that version remain on disk.
final class AssetServerClient {
    private let baseURL: URL
    private let session: URLSession
    private let fileManager: FileManager

    init(baseURL: URL, session: URLSession = .shared, fileManager: FileManager = .default) {
        self.baseURL = baseURL
        self.session = session
        self.fileManager = fileManager
    }

    /// Syncs all display slots for the selected app/version and returns the local file for one slot.
    /// Existing files are reused only after their SHA-256 has been verified.
    func syncAndResolve(appID: String, version: String, slot: String) async throws -> (url: URL, downloaded: Int, reused: Int) {
        let catalog = try await fetchSlotCatalog(appID: appID, version: version)
        let directory = try assetDirectory()
        var assignments: [String: CachedAsset] = [:]
        var downloaded = 0
        var reused = 0

        // Do not change the local manifest or prune files until every current assignment is valid.
        for remoteSlot in catalog.slots {
            guard let assignment = remoteSlot.assignment else { continue }
            let asset = assignment.asset
            let safeName = URL(fileURLWithPath: asset.name).lastPathComponent
            let fileName = asset.id + "-" + safeName
            let destination = directory.appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: destination.path),
               (try? Self.sha256(fileAt: destination)).map({ $0.caseInsensitiveCompare(asset.sha256) == .orderedSame }) == true {
                reused += 1
            } else {
                try await download(asset, to: destination)
                downloaded += 1
            }
            assignments[remoteSlot.slot] = CachedAsset(id: asset.id, name: asset.name,
                contentType: asset.contentType, sha256: asset.sha256, fileName: fileName)
        }

        let localManifest = LocalAssetManifest(schemaVersion: 1, appId: appID, version: version,
            syncedAt: Date(), assignments: assignments)
        try save(localManifest)

        let retainedFiles = Set(assignments.values.map(\.fileName))
        for fileURL in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where fileURL.lastPathComponent != "manifest.json" && !retainedFiles.contains(fileURL.lastPathComponent) {
            try fileManager.removeItem(at: fileURL)
        }
        // Remove files left behind by the earlier sample implementation, which used Documents/DownloadedAssets.
        try removeLegacyDownloadedAssets()

        guard let selected = assignments[slot] else { throw AssetServerError.noAssignment(slot) }
        return (directory.appendingPathComponent(selected.fileName), downloaded, reused)
    }

    /// Fetches a published protocol document and its generated file manifest, then validates their identity,
    /// typed document structure, and every assetID reference before handing content to a renderer.
    func fetchAndValidateInteractiveContent(appID: String, version: String, contentID: String) async throws -> ValidatedInteractiveContent {
        let contentURL = baseURL.appendingPathComponent("api/v1/apps").appendingPathComponent(appID)
            .appendingPathComponent("versions").appendingPathComponent(version)
            .appendingPathComponent("interactive-content").appendingPathComponent(contentID)
        let contentData = try await get(contentURL)
        let published = try JSONDecoder().decode(PublishedInteractiveContent.self, from: contentData)
        guard published.protocolVersion == "1.0", published.appId == appID,
              published.version == version, published.id == contentID else {
            throw AssetServerError.invalidInteractiveContent("protocol version, app ID, version, or content ID does not match the request")
        }

        // Decode into the shared Swift protocol models for the supported structured content types.
        let documentData = try JSONEncoder().encode(published.document)
        do {
            switch published.type {
            case "sticker-library": _ = try JSONDecoder().decode(StickerLibraryDocument.self, from: documentData)
            case "sticker-pack": _ = try JSONDecoder().decode(StickerPackDocument.self, from: documentData)
            case "animated-message-bubble": _ = try JSONDecoder().decode(AnimatedMessageBubbleDocument.self, from: documentData)
            case "fullscreen-animation": _ = try JSONDecoder().decode(FullscreenAnimationDocument.self, from: documentData)
            case "sticker": _ = try JSONDecoder().decode(StickerDocument.self, from: documentData)
            default: throw AssetServerError.invalidInteractiveContent("unsupported content type \(published.type)")
            }
        } catch let error as AssetServerError {
            throw error
        } catch {
            throw AssetServerError.invalidInteractiveContent("document does not decode as \(published.type): \(error.localizedDescription)")
        }

        let manifestURL = baseURL.appendingPathComponent("api/v1/apps").appendingPathComponent(appID)
            .appendingPathComponent("versions").appendingPathComponent(version)
            .appendingPathComponent("interactive-manifests").appendingPathComponent(contentID)
        let manifest = try JSONDecoder().decode(InteractiveProtocolManifest.self, from: await get(manifestURL))
        guard manifest.protocolVersion == published.protocolVersion,
              manifest.contentID == published.id, manifest.contentType == published.type,
              manifest.contentVersion == published.contentVersion else {
            throw AssetServerError.invalidInteractiveContent("asset manifest does not match the published document")
        }
        let refs = Self.assetReferences(in: published.document)
        let manifestIDs = manifest.files.map(\.id)
        guard Set(manifestIDs).count == manifestIDs.count,
              Set(refs) == Set(manifestIDs) else {
            throw AssetServerError.invalidInteractiveContent("assetID references and manifest file IDs do not match")
        }
        for file in manifest.files {
            guard file.byteCount >= 0, file.sha256.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil,
                  URL(fileURLWithPath: file.fileName).lastPathComponent == file.fileName else {
                throw AssetServerError.invalidInteractiveContent("invalid file metadata for \(file.id)")
            }
        }
        return ValidatedInteractiveContent(published: published, manifest: manifest, referencedAssetIDs: refs.sorted())
    }

    private static func assetReferences(in value: InteractiveJSONValue) -> [String] {
        switch value {
        case .object(let object):
            var result: [String] = []
            if let id = object["assetID"]?.stringValue { result.append(id) }
            for child in object.values { result.append(contentsOf: assetReferences(in: child)) }
            return result
        case .array(let values): return values.flatMap(assetReferences(in:))
        default: return []
        }
    }

    /// If the server is unavailable, the last successful manifest can still serve an already-downloaded asset.
    func resolveFromPersistentStore(appID: String, version: String, slot: String) throws -> URL? {
        guard let manifest = try? loadLocalManifest(), manifest.appId == appID, manifest.version == version,
              let asset = manifest.assignments[slot] else { return nil }
        let url = try assetDirectory().appendingPathComponent(asset.fileName)
        guard fileManager.fileExists(atPath: url.path),
              (try? Self.sha256(fileAt: url)).map({ $0.caseInsensitiveCompare(asset.sha256) == .orderedSame }) == true else { return nil }
        return url
    }

    private func fetchSlotCatalog(appID: String, version: String) async throws -> SlotCatalogResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/slots"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "version", value: version), URLQueryItem(name: "appId", value: appID)]
        let data = try await get(components.url!)
        let catalog = try JSONDecoder().decode(SlotCatalogResponse.self, from: data)
        guard catalog.appId == appID, catalog.version == version else { throw AssetServerError.invalidResponse }
        return catalog
    }

    private func download(_ asset: RemoteAsset, to destination: URL) async throws {
        guard let url = URL(string: asset.downloadUrl, relativeTo: baseURL)?.absoluteURL else {
            throw AssetServerError.invalidResponse
        }
        let (temporaryURL, response) = try await session.download(from: url)
        guard let response = response as? HTTPURLResponse else { throw AssetServerError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw AssetServerError.httpStatus(response.statusCode) }
        let digest = try Self.sha256(fileAt: temporaryURL)
        guard digest.caseInsensitiveCompare(asset.sha256) == .orderedSame else {
            throw AssetServerError.checksumMismatch(asset.name)
        }
        try fileManager.removeItemIfExists(at: destination)
        try fileManager.moveItem(at: temporaryURL, to: destination)
    }

    private func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else { throw AssetServerError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw AssetServerError.httpStatus(response.statusCode) }
        return data
    }

    private func assetDirectory() throws -> URL {
        let applicationSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = applicationSupport.appendingPathComponent("AssetServer/Assets", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
        return directory
    }

    private func manifestURL() throws -> URL {
        try assetDirectory().appendingPathComponent("manifest.json", isDirectory: false)
    }

    private func removeLegacyDownloadedAssets() throws {
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let legacyDirectory = documents.appendingPathComponent("DownloadedAssets", isDirectory: true)
        try fileManager.removeItemIfExists(at: legacyDirectory)
    }

    private func save(_ manifest: LocalAssetManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let url = try manifestURL()
        try data.write(to: url, options: .atomic)
    }

    private func loadLocalManifest() throws -> LocalAssetManifest {
        try JSONDecoder().decode(LocalAssetManifest.self, from: Data(contentsOf: manifestURL()))
    }

    private static func sha256(fileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) { try removeItem(at: url) }
    }
}
