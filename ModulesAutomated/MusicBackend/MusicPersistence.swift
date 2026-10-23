import Foundation

public enum MusicPersistenceError: Error, LocalizedError {
    case invalidIdentifier
    case invalidPlaylistPayload
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier: return "Invalid playlist identifier"
        case .invalidPlaylistPayload: return "Playlist payload must be a JSON object"
        case .io(let message): return message
        }
    }
}

/// File-backed implementation of the music playlist/session persistence contract.
public final class MusicPersistence {
    public typealias Clock = () -> Int64
    public typealias IDGenerator = () -> String

    public let directoryURL: URL
    private let fileManager: FileManager
    private let clock: Clock
    private let idGenerator: IDGenerator

    public init(directoryURL: URL, fileManager: FileManager = .default, clock: @escaping Clock = { Int64(Date().timeIntervalSince1970 * 1000) }, idGenerator: @escaping IDGenerator = { UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased() }) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public convenience init(directoryPath: String) {
        self.init(directoryURL: URL(fileURLWithPath: directoryPath, isDirectory: true))
    }

    public static func sanitizedPlaylistID(_ input: String, fallback: @escaping () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased() }) -> String {
        let allowed = input.unicodeScalars.filter { scalar in
            (scalar.value >= 48 && scalar.value <= 57) ||
            (scalar.value >= 65 && scalar.value <= 90) ||
            (scalar.value >= 97 && scalar.value <= 122) || scalar == "_" || scalar == "-"
        }
        let cleaned = String(String.UnicodeScalarView(allowed)).prefix(48)
        if !cleaned.isEmpty { return String(cleaned) }
        return "pl_\(fallback())"
    }

    private func ensureDirectory() throws {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw MusicPersistenceError.io(error.localizedDescription)
        }
    }

    private func playlistURL(for id: String) throws -> URL {
        let safeID = Self.sanitizedPlaylistID(id, fallback: idGenerator)
        guard !safeID.isEmpty else { throw MusicPersistenceError.invalidIdentifier }
        return directoryURL.appendingPathComponent("playlist_\(safeID).json", isDirectory: false)
    }

    private func readPlaylist(at url: URL) -> MusicPlaylist? {
        guard let data = try? Data(contentsOf: url),
              let playlist = try? JSONDecoder().decode(MusicPlaylist.self, from: data),
              !playlist.id.isEmpty else { return nil }
        return playlist
    }

    /// Returns valid playlists sorted by filename. If none exist, writes defaults and returns those defaults.
    public func listPlaylists() throws -> [MusicPlaylist] {
        try ensureDirectory()
        let urls = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("playlist_") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result = urls.compactMap(readPlaylist(at:))
        if result.isEmpty {
            for playlist in MusicDefaults.playlists {
                try writePlaylist(playlist)
            }
            result = MusicDefaults.playlists
        }
        return result
    }

    @discardableResult
    public func writePlaylist(_ playlist: MusicPlaylist) throws -> MusicPlaylist {
        try ensureDirectory()
        let safeID = Self.sanitizedPlaylistID(playlist.id, fallback: idGenerator)
        var normalized = playlist
        normalized.name = playlist.name.isEmpty ? "未命名歌单" : playlist.name
        normalized.tracks = playlist.tracks.map { value in
            guard case .object(var track) = value else { return value }
            if track["coverUrl"] == nil || track["coverUrl"] == .null { track["coverUrl"] = .string("") }
            if track["url"] == nil || track["url"] == .null { track["url"] = .string("") }
            return .object(track)
        }
        normalized.updatedAt = clock()
        // Keep the canonical safe ID in both the filename and payload.
        normalized.id = safeID
        let url = directoryURL.appendingPathComponent("playlist_\(safeID).json", isDirectory: false)
        do {
            try JSONEncoder.prettyMusic.encode(normalized).write(to: url, options: .atomic)
        } catch {
            throw MusicPersistenceError.io(error.localizedDescription)
        }
        return normalized
    }

    public func deletePlaylist(id: String) throws -> Bool {
        try ensureDirectory()
        let url = try playlistURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return false }
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            throw MusicPersistenceError.io(error.localizedDescription)
        }
    }

    public func readSession() -> [String: JSONValue] {
        let url = directoryURL.appendingPathComponent("_session.json", isDirectory: false)
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONValue.decodeJSON(from: data),
              let object = value.objectValue else {
            return MusicDefaults.idleSession(nowMilliseconds: clock())
        }
        return object
    }

    public func writeSession(_ session: [String: JSONValue]) throws {
        try ensureDirectory()
        let url = directoryURL.appendingPathComponent("_session.json", isDirectory: false)
        do {
            try JSONValue.object(session).encodedData(prettyPrinted: true).write(to: url, options: .atomic)
        } catch {
            throw MusicPersistenceError.io(error.localizedDescription)
        }
    }
}

private extension JSONEncoder {
    static var prettyMusic: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
