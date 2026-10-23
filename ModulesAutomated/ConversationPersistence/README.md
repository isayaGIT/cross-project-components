# ConversationPersistence

Native Swift persistence layer corresponding to `cloud/services/save/`. It keeps branching story conversations and linear private-chat history in separate storage systems and exposes a common `SaveStore` contract.

## Source mapping

- `cloud/services/save/__init__.py`: channel selection and public facade → `ConversationPersistence.store(for:)`.
- `cloud/services/save/types.py`: `chat` and `private` channel constants → `SaveChannel`.
- `cloud/services/save/flags.py`: environment-backed write-disable gate → `SaveWriteGate`.
- `cloud/services/save/store.py`: unified storage protocol → `SaveStore`.
- `cloud/services/save/story.py`: JSON document storage, safe chat IDs, atomic full writes, incremental patches, active-path traversal and window retrieval → `StorySaveStore`.
- `cloud/services/save/private.py`: SQLite schema and migration, message CRUD, pagination and query helpers → `PrivateSaveStore`.

## Architecture

`ConversationPersistence` owns immutable storage configuration and a shared write gate. `store(for:)` accepts the wire channel values `chat` or `private` and returns a channel-specific implementation. The story implementation writes one JSON document per chat at `<root>/<chat-id>.json`. The private implementation uses `<root>/private_chat/private_chat.db` and separate `images`, `audio`, `recalled`, and `persona` directories. No UI, HTTP handler, LLM provider, or network dependency is included.

The implementation uses Foundation, Swift concurrency-compatible protocol signatures, and SQLite3. The caller must make the SQLite3 module available in the target build environment. Storage methods throw typed errors for I/O, invalid identifiers, and SQLite failures; validation failures that were result dictionaries in Python are represented as `SaveOperationResult` errors where practical.

## Configuration

Provide a root directory representing the Python backend's `saves` directory. Do not pass the `private_chat` directory itself as the root: private storage appends that directory, while story JSON files are stored directly in the root. `SaveWriteGate` reads `SAVE_DISABLED` from the process environment by default. Calling `setDisabled(true)` disables writes; `setDisabled(false)` enables writes regardless of the environment; `setDisabled(nil)` restores environment-driven behavior.

```swift
import Foundation
import ConversationPersistence

let root = URL(fileURLWithPath: savesDirectory, isDirectory: true)
let gate = SaveWriteGate()
let persistence = ConversationPersistence(
    configuration: SavePersistenceConfiguration(rootDirectory: root),
    writeGate: gate
)
let story = try persistence.store(for: "chat")
let privateStore = try persistence.store(for: "private")
```

Use `StorySaveStore.saveDocument(_:)` for full documents and `patchDocument(_:)` for incremental patches. Story `loadWindow(chatID:limit:before:full:)` accepts a message ID for `before`. Private `insertMessage`, `loadWindow`, `deleteMessage`, `recallMessage`, `updateMessage`, and query helpers expose message-level persistence operations. The protocol-based `upsert`, `loadWindow`, and `patchMeta` methods provide a shared integration surface.

## Behavior and compatibility

Story message nodes remain JSON objects keyed by node ID. The active path follows `activeBranches` and falls back to the first child, stopping at missing nodes or cycles. Window responses include parent nodes and sibling branches needed to render the selected path. Legacy flat story messages are returned whole so a higher layer can migrate them, and patch attempts on such documents return a typed `legacyFlatDocumentRequiresFullSave` error.

Private messages preserve the existing SQLite column names and camel-case JSON message keys. Pagination sorts newest-first in SQL, fetches one extra row for `hasMore`, and returns selected messages in chronological order. Client IDs are bounded to 64 characters and protected by a unique partial index for idempotent inserts. Sticker normalization is injected; if sticker validation is requested without a catalog and normalizer, insertion returns a configuration error rather than accepting an unvalidated sticker.

Database initialization adds missing legacy columns and creates the timestamp and client-ID indexes. A legacy root-level `private_chat.db` and files under `private_persona` are migrated into the private subdirectory. Passing `migrateLegacyAudioFrom:` to `ensureDatabase` moves referenced MP3 files from the legacy audio directory when destinations do not already exist. Filesystem migration errors for individual persona/audio files are intentionally non-fatal, matching the best-effort nature of the Python implementation.

## Limitations

This initial port is partial. The complete Python `append_assistant_parts` behavior (including line splitting, injectable clock, and broadcast callback) is not yet exposed. Some Python APIs return untyped dictionaries and have nuanced behavior for malformed legacy data; this implementation provides typed errors and JSON values instead. Verify SQLite3 module availability and compile integration in the consuming project. No tests or build commands are included in this deliverable.
