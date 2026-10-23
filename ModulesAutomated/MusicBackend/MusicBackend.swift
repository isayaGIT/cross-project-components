import Foundation

/// Public facade for local music persistence and NetEase Cloud Music operations.
public final class MusicBackend {
    public let persistence: MusicPersistence
    public let netEase: NetEaseMusicClient

    public init(storageDirectory: URL, netEaseClient: NetEaseMusicClient = NetEaseMusicClient()) {
        self.persistence = MusicPersistence(directoryURL: storageDirectory)
        self.netEase = netEaseClient
    }

    public init(persistence: MusicPersistence, netEaseClient: NetEaseMusicClient = NetEaseMusicClient()) {
        self.persistence = persistence
        self.netEase = netEaseClient
    }

    public func listPlaylists() throws -> [MusicPlaylist] {
        try persistence.listPlaylists()
    }

    @discardableResult
    public func savePlaylist(_ playlist: MusicPlaylist) throws -> MusicPlaylist {
        try persistence.writePlaylist(playlist)
    }

    public func deletePlaylist(id: String) throws -> Bool {
        try persistence.deletePlaylist(id: id)
    }

    public func currentSession() -> [String: JSONValue] {
        persistence.readSession()
    }

    public func saveSession(_ session: [String: JSONValue]) throws {
        try persistence.writeSession(session)
    }

    public func providerStatus() -> NetEaseMusicStatus { netEase.status }

    public func searchSongs(_ keyword: String, limit: Int = 30) async throws -> [NetEaseSong] {
        try await netEase.searchSongs(keyword: keyword, limit: limit)
    }

    public func resolvePlayURL(songID: String) async throws -> String {
        try await netEase.playURL(songID: songID)
    }

    public func songDetail(id: String) async throws -> NetEaseSongDetail {
        try await netEase.songDetail(songID: id)
    }

    public func playlistDetail(id: String) async throws -> NetEasePlaylistDetail {
        try await netEase.playlistDetail(playlistID: id)
    }
}
