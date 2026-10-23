# MusicBackend

A reusable Swift subsystem extracted from `cloud/services/music.py` and `cloud/services/netease_music.py`.

## Responsibilities

- File-backed playlist persistence and default playlist seeding.
- Safe playlist filename generation, malformed-file tolerance, and timestamped playlist writes.
- Session persistence with a stable idle-session fallback.
- NetEase Cloud Music API configuration, status reporting, song search, play URL resolution, song details, and playlist details.
- Typed Swift errors and injectable HTTP transport for controlled integration.

## Integration

```swift
import Foundation

let storage = URL(fileURLWithPath: "~/Library/Application Support/MyApp/Music", isDirectory: true)
let configuration = NetEaseMusicConfiguration.fromEnvironment()
let client = NetEaseMusicClient(configuration: configuration)
let music = MusicBackend(storageDirectory: storage, netEaseClient: client)

let playlists = try music.listPlaylists()
let session = music.currentSession()
let providerStatus = music.providerStatus()
```

Network operations are asynchronous and throw `MusicBackendError` values:

```swift
let songs = try await music.searchSongs("关键词", limit: 30)
let url = try await music.resolvePlayURL(songID: songs[0].nid)
let details = try await music.songDetail(id: songs[0].nid)
let remotePlaylist = try await music.playlistDetail(id: "123456")
```

## Persistence contract

Playlist files are named `playlist_<safe-id>.json`; the session file is `_session.json`. Playlist data retains unknown top-level fields, and tracks are stored as raw `JSONValue` entries so non-object or future track shapes are not discarded. `MusicPlaylist.typedTracks` provides a convenient typed view for object-shaped tracks. Playlist writes normalize missing/null `url` and `coverUrl` fields to empty strings and refresh `updatedAt` using Unix epoch milliseconds. Unknown session keys are retained.

The default playlist set is defined in `MusicDefaults.playlists`. If the directory has no valid playlist files, defaults are written and returned. If the session file is missing, malformed, or not a JSON object, `readSession()` returns the idle-session shape.

## Provider configuration

- `NETEASE_MUSIC_BASE_URL`: optional API base URL. Only HTTP(S) URLs are accepted; invalid values fall back to `https://netease.xbattle.tech`.
- `NETEASE_MUSIC_COOKIE`: cookie string required to make API requests.

The status object exposes only whether a cookie exists; it never returns the cookie value. Requests include the `https://music.163.com/` referer and a configurable 15-second default timeout. The cookie is passed as a query parameter to match the source service contract, so use a trusted API endpoint and avoid logging full request URLs.

## Error mapping

The Swift API uses throwing functions rather than Python-style `(result, error)` tuples. Configuration, HTTP status, transport, malformed response, and provider-level failures are represented by `MusicBackendError`. Play URL resolution intentionally tries the standard high-quality endpoint and then the unblock fallback before returning the source-compatible copyright/Cookie error.

## Dependency injection

`MusicPersistence` accepts a directory URL, clock, and ID generator. `NetEaseMusicClient` accepts a configuration and `MusicHTTPTransport`, allowing callers to supply a mock transport or a custom URLSession-backed transport without changing the subsystem API.
