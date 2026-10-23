# KaomojiStore

A reusable native Swift backend subsystem migrated from `cloud/services/kaomoji_store.py`. It contains no UI code and uses Foundation JSON and filesystem APIs.

## Source mapping

- `cloud/services/kaomoji_store.py`: directory and path resolution, default schema, string/category cleanup, defensive loading, legacy custom-file migration, and persistence.
- `KaomojiStoreModels.swift`: typed store/category contracts, normalization, Python-like JSON value conversion, and typed errors.
- `KaomojiStoreService.swift`: actor-isolated filesystem access, primary-store load/save, and legacy migration.

## Storage layout

Given a caller-provided saves root, the primary file is `<savesRoot>/Stickers/kaomoji/store.json`. The optional legacy custom file is supplied separately as `legacyCustomFileURL`. No application-specific absolute path is embedded in this module.

## Public API

- `KaomojiStore`: Codable, Equatable, Sendable normalized model with `categories`, `favorites`, `recent`, and `activePack`.
- `KaomojiStore.Category`: a named category with its kaomoji strings.
- `KaomojiStore.empty`: the default store.
- `KaomojiStore.normalized()`: normalizes an existing typed value.
- `KaomojiStore.normalize(jsonData:)`: decodes arbitrary JSON data and applies source-compatible root normalization; a non-object root becomes the default store, while invalid JSON throws `KaomojiStoreError.invalidJSON`.
- `KaomojiStoreService.Configuration`: the saves root and optional legacy custom-file URL.
- `KaomojiStoreService.directoryURL()` and `storeURL()`: resolve the storage directory and primary file URL.
- `KaomojiStoreService.load()`: reads the primary store, falls back to legacy categories or defaults, and suppresses load/migration errors as the Python source does.
- `KaomojiStoreService.save(_:)`: normalizes and persists a typed store, throwing on directory, encoding, or write failures.
- `KaomojiStoreService.saveJSONData(_:)`: decodes, normalizes, and persists a JSON document supplied as `Data`.

## Normalization behavior

The normalized root object contains only `categories`, `favorites`, `recent`, and `activePack`. The default active pack is `kaomoji`. Limits are 40 categories, 32 Unicode scalars per category name, 80 items per category, 80 favorites, and 48 recent entries. Each string-list item and active pack is limited to 64 Unicode scalars. Strings are trimmed; empty list values are removed; duplicates are removed while preserving order. The input list is sliced to its maximum size before filtering, matching the source's `raw[:limit]` behavior.

The active pack uses Python-style truthiness for common JSON values before conversion and trimming. JSON null converts to `None` when stringified as a category name or list item, consistent with Python `str(None)`. Booleans stringify as `True` or `False`. Arrays and objects use a Python-like representation. This conversion is designed for JSON-compatible values; it is not a general Python object serializer.

## Legacy migration

The legacy file may contain a root JSON array of categories or an object with a `categories` array. When the primary store is missing, malformed, or not an object and the configured legacy file exists, the service normalizes the legacy categories or defaults, attempts to save the new store, and then attempts to rename the legacy file to a `.json.migrated` suffix. Failed saves and renames do not prevent returning the normalized result. Only the explicitly configured legacy path is considered.

## Example

```swift
let service = KaomojiStoreService(
    configuration: .init(
        savesRoot: savesDirectoryURL,
        legacyCustomFileURL: legacyKaomojiURL
    )
)

let current = await service.load()
var updated = current
updated.favorites.insert("(＾▽＾)", at: 0)
let saved = try await service.save(updated)
print(saved.activePack)
```

To normalize an arbitrary JSON document without writing it:

```swift
let normalized = try KaomojiStore.normalize(jsonData: jsonData)
```

To normalize and persist it in one operation:

```swift
let saved = try await service.saveJSONData(jsonData)
```

## Dependency injection and concurrency

The saves root and legacy file URL are caller-supplied, and `FileManager` can be injected. Each service instance is an actor and serializes operations made through that instance. Multiple service instances targeting the same directory are not coordinated and should be managed by the caller.

## Limitations

- This is a backend persistence component only; it does not implement HTTP routes, UI, or browser-side behavior.
- `load()` intentionally suppresses read and migration errors; use `save(_:)` for explicit persistence failure reporting.
- Foundation JSON serialization does not guarantee byte-for-byte identical whitespace or dictionary key ordering to Python's `json.dumps`, though the normalized schema and Unicode content are preserved.
- The legacy migration behavior depends on the caller providing the correct legacy file URL.
