import Foundation

public struct MusicTrack: Codable, Equatable, Sendable {
    public var id: String?
    public var title: String?
    public var artist: String?
    public var url: String
    public var coverURL: String
    public var extra: [String: JSONValue]

    public init(id: String? = nil, title: String? = nil, artist: String? = nil, url: String = "", coverURL: String = "", extra: [String: JSONValue] = [:]) {
        self.id = id
        self.title = title
        self.artist = artist
        self.url = url
        self.coverURL = coverURL
        self.extra = extra
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, url
        case coverURL = "coverUrl"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "id")!)
        title = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "title")!)
        artist = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "artist")!)
        url = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "url")!)) ?? ""
        coverURL = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "coverUrl")!)) ?? ""
        let known: Set<String> = ["id", "title", "artist", "url", "coverUrl"]
        var unknown: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            if let value = try? container.decode(JSONValue.self, forKey: key) {
                unknown[key.stringValue] = value
            }
        }
        extra = unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in extra where !["id", "title", "artist", "url", "coverUrl"].contains(key) {
            try container.encode(value, forKey: DynamicCodingKey(stringValue: key)!)
        }
        try container.encodeIfPresent(id, forKey: DynamicCodingKey(stringValue: "id")!)
        try container.encodeIfPresent(title, forKey: DynamicCodingKey(stringValue: "title")!)
        try container.encodeIfPresent(artist, forKey: DynamicCodingKey(stringValue: "artist")!)
        try container.encode(url, forKey: DynamicCodingKey(stringValue: "url")!)
        try container.encode(coverURL, forKey: DynamicCodingKey(stringValue: "coverUrl")!)
    }

    /// Builds a typed view of a raw track object without requiring callers to discard unknown fields.
    public static func from(raw value: JSONValue) -> MusicTrack? {
        guard let object = value.objectValue else { return nil }
        let known: Set<String> = ["id", "title", "artist", "url", "coverUrl"]
        var extra = object.filter { !known.contains($0.key) }
        return MusicTrack(
            id: object["id"]?.stringValue,
            title: object["title"]?.stringValue,
            artist: object["artist"]?.stringValue,
            url: object["url"]?.stringValue ?? "",
            coverURL: object["coverUrl"]?.stringValue ?? "",
            extra: extra
        )
    }
}

public struct MusicPlaylist: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// Raw JSON tracks are retained so unusual or future track formats are not silently lost.
    public var tracks: [JSONValue]
    public var updatedAt: Int64?
    public var extra: [String: JSONValue]

    public init(id: String, name: String = "未命名歌单", tracks: [JSONValue] = [], updatedAt: Int64? = nil, extra: [String: JSONValue] = [:]) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.updatedAt = updatedAt
        self.extra = extra
    }

    public var typedTracks: [MusicTrack] { tracks.compactMap(MusicTrack.from(raw:)) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "id")!)) ?? ""
        name = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "name")!)) ?? "未命名歌单"
        tracks = (try? container.decode([JSONValue].self, forKey: DynamicCodingKey(stringValue: "tracks")!)) ?? []
        if let number = try? container.decode(Int64.self, forKey: DynamicCodingKey(stringValue: "updatedAt")!) {
            updatedAt = number
        } else {
            updatedAt = nil
        }
        let known: Set<String> = ["id", "name", "tracks", "updatedAt"]
        var unknown: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            if let value = try? container.decode(JSONValue.self, forKey: key) { unknown[key.stringValue] = value }
        }
        extra = unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        let known: Set<String> = ["id", "name", "tracks", "updatedAt"]
        for (key, value) in extra where !known.contains(key) {
            try container.encode(value, forKey: DynamicCodingKey(stringValue: key)!)
        }
        try container.encode(id, forKey: DynamicCodingKey(stringValue: "id")!)
        try container.encode(name, forKey: DynamicCodingKey(stringValue: "name")!)
        try container.encode(tracks, forKey: DynamicCodingKey(stringValue: "tracks")!)
        try container.encodeIfPresent(updatedAt, forKey: DynamicCodingKey(stringValue: "updatedAt")!)
    }
}

public enum MusicDefaults {
    public static let playlists: [MusicPlaylist] = [
        MusicPlaylist(id: "favorites", name: "我喜欢的音乐", extra: ["isDefault": .bool(true)]),
        MusicPlaylist(id: "recently-played", name: "最近播放", extra: ["isDefault": .bool(true)]),
        MusicPlaylist(id: "my-playlist", name: "我的歌单", extra: ["isDefault": .bool(true)])
    ]

    public static func idleSession(nowMilliseconds: Int64) -> [String: JSONValue] {
        [
            "status": .string("idle"),
            "playlistId": .null,
            "trackIndex": .number(0),
            "isPlaying": .bool(false),
            "position": .number(0),
            "inviteStatus": .null,
            "updatedAt": .number(Double(nowMilliseconds))
        ]
    }
}

public struct NetEaseSong: Codable, Equatable, Sendable {
    public let nid: String
    public let title: String
    public let artist: String
    public let albumName: String
    public let coverURL: String
    public let duration: Int

    enum CodingKeys: String, CodingKey {
        case nid, title, artist, albumName
        case coverURL = "coverUrl"
        case duration
    }

    public init(nid: String, title: String, artist: String, albumName: String, coverURL: String, duration: Int) {
        self.nid = nid
        self.title = title
        self.artist = artist
        self.albumName = albumName
        self.coverURL = coverURL
        self.duration = duration
    }

    public static func normalize(_ value: JSONValue) -> NetEaseSong? {
        guard let object = value.objectValue,
              let rawID = object["id"],
              let rawName = object["name"] else { return nil }
        let id = rawID.stringValue ?? rawID.intValue.map(String.init) ?? ""
        let title = rawName.stringValue ?? ""
        let artistValue = object["ar"] ?? object["artists"]
        let artists: String
        if let list = artistValue?.arrayValue {
            artists = list.compactMap { item in
                guard let artist = item.objectValue else { return nil }
                return artist["name"]?.stringValue
            }.joined(separator: "/")
        } else {
            artists = artistValue?.stringValue ?? ""
        }
        let albumValue = object["al"] ?? object["album"]
        let album = albumValue?.objectValue
        let albumName = album?["name"]?.stringValue ?? albumValue?.stringValue ?? ""
        let coverURL = album?["picUrl"]?.stringValue ?? album?["pic_url"]?.stringValue ?? ""
        let durationMilliseconds = (object["dt"]?.intValue).flatMap { $0 == 0 ? nil : $0 }
            ?? (object["duration"]?.intValue).flatMap { $0 == 0 ? nil : $0 }
            ?? 0
        return NetEaseSong(nid: id, title: title, artist: artists, albumName: albumName, coverURL: coverURL, duration: max(0, durationMilliseconds / 1000))
    }
}

public struct NetEaseSongDetail: Codable, Equatable, Sendable {
    public let song: NetEaseSong
    public let raw: JSONValue
    public init(song: NetEaseSong, raw: JSONValue) { self.song = song; self.raw = raw }
}

public struct NetEasePlaylistDetail: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let coverURL: String
    public let trackCount: Int
    public let tracks: [NetEaseSong]
    public let raw: JSONValue

    public init(id: String, name: String, coverURL: String, trackCount: Int, tracks: [NetEaseSong], raw: JSONValue) {
        self.id = id
        self.name = name
        self.coverURL = coverURL
        self.trackCount = trackCount
        self.tracks = tracks
        self.raw = raw
    }
}
