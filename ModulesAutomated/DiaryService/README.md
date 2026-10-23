# DiaryService

A standalone Swift port of `cloud/services/diary.py`.

## Files

- `DiaryModels.swift` defines JSON-preserving diary models, summaries, reflection results, and month-calendar output.
- `DiaryService.swift` implements date handling, entry persistence, summaries, index listing, month calendars, prompt building, and reflection updates.

## Usage

```swift
import Foundation

let diaryRoot = URL(fileURLWithPath: "/path/to/diary", isDirectory: true)
let diary = DiaryService(rootDirectory: diaryRoot)

let today = await diary.safeDate(nil)
var entry = await diary.readEntry(for: today)
entry.user.content = "今天完成了一件重要的事。"
try await diary.writeEntry(entry, for: today)

let compact = await diary.daySummary(entry)
let prompt = await diary.buildReflectionPrompt(entry: entry)
print(compact.userPreview)
print(prompt)
```

## Behavioral notes

- Date validation intentionally checks only the `YYYY-MM-DD` shape, matching the Python source; impossible dates with the correct shape are not rejected by `safeDate`.
- The default timezone follows the current system timezone, matching `time.strftime` behavior more closely than a fixed timezone. Supply a custom timezone and `dateProvider` when deterministic date behavior is required.
- Missing files and invalid JSON return an empty entry. Filesystem write errors are surfaced as `ServiceError` cases.
- Unknown entry and section keys and arbitrary JSON `tags` values are preserved through reads and writes.
- Index filenames are sorted descending and the limit is applied before date-stem validation, matching Python's list slicing order, including negative limits.
- Compact summaries omit full-content fields during encoding; sticker fields are encoded as JSON null when absent.
- Reflection prompts use the supplied system prompt constants separately from the user prompt body, matching the source service's separation of system and request prompts.
- `applyReflectionResult` updates `updatedAt` in milliseconds and updates `scheduledAt` only when `scheduled` is true. It only replaces the sticker when the parsed sticker is nonempty.

## Integration

Add both Swift files to the same target. The service is an actor so file operations and mutations are serialized per instance. Its I/O closures can be replaced for alternate storage backends. No other backend subsystem is required.