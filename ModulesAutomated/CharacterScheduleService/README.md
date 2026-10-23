# CharacterScheduleService

A reusable Swift migration of `cloud/services/schedule.py`. The subsystem uses Foundation and dependency injection, so it does not require a particular web-search service, LLM vendor, credentials, or app runtime.

## Files

- `ScheduleModels.swift`: default configuration, JSON conversion helpers, storage paths, shared options, result type, and errors.
- `ScheduleTime.swift`: date normalization, clock parsing, weekday selection, sleep overlap, block filtering, and current-block lookup.
- `SchedulePersistence.swift`: template, daily schedule, and runtime-state JSON file persistence.
- `CharacterScheduleService.swift`: generation, prompt construction, response parsing, fallback schedules, runtime-state resolution, and prompt-block formatting.

## Integration

Create the storage URLs appropriate to the host app and inject its model/search functions:

```swift
let paths = ScheduleStoragePaths(
    templateURL: applicationSupport.appendingPathComponent("schedule_template.json"),
    dailyDirectoryURL: applicationSupport.appendingPathComponent("daily", isDirectory: true),
    stateURL: applicationSupport.appendingPathComponent("schedule_state.json")
)
let store = ScheduleFileStore(paths: paths)
let service = CharacterScheduleService(
    store: store,
    llmCall: { prompt in
        // Call the host application's configured LLM and return its text response.
        return try await modelClient.generateText(prompt: prompt)
    },
    inspirationSearch: { query, limit, mode in
        // Return dictionaries containing `title` and `snippet` from the host search adapter.
        return try await searchClient.search(query: query, limit: limit, mode: mode)
    }
)
let options = ScheduleGenerationOptions(
    dateString: nil,
    now: Date(),
    calendar: Calendar(identifier: .gregorian),
    sleepState: ScheduleSleepState.awake,
    lifestyleContext: "角色的生活习惯与背景",
    personaText: "角色设定原文"
)
let result = try await service.resolveToday(options: options)
print(result.promptBlock)
```

The example's `modelClient` and `searchClient` are host-provided adapters, not APIs defined by this module. If no LLM closure is injected, the service uses the template fallback. Inspiration search is optional and failures are ignored.

## Persistence contract

- Template JSON is read from `templateURL`; valid object contents are shallow-merged over `ScheduleDefaults.template`, matching the source behavior.
- Daily files are named `daily_YYYY-MM-DD.json` inside `dailyDirectoryURL`.
- Runtime state is read and written at `stateURL`.
- Daily writes create the daily directory and normalize the stored date. Template writes create their parent directory. State writes intentionally do not create the parent directory, matching the source's `save_state` behavior.
- JSON dictionaries are retained at the public boundary to preserve unrecognized fields. Generated blocks are normalized to the known source fields.

## Compatibility notes

- Weekday numbering follows Python: Monday is `0`, Sunday is `6`.
- Date normalization checks the `YYYY-MM-DD` shape, as the source does; it does not reject impossible calendar dates until calendar-dependent operations are requested.
- Time values are represented as minutes after midnight. Intervals crossing midnight are supported. As in the source, an equal start/end interval follows the wrapping-interval branch in current-block lookup.
- Sleep overlap uses half-open intervals and excludes touching-only boundaries.
- The source's Chinese labels and prompt intent are retained. The exact default template values live in `ScheduleDefaults.template` and can be replaced by the host's template file.
- `ScheduleGenerationOptions.calendar` and `now` make time-sensitive behavior injectable. Configure the calendar and timezone to match the intended schedule timezone; the template's `timezone` field is preserved as configuration and is not silently applied to the process calendar.
- Search and model operations are injected closures. The module does not fabricate provider APIs or silently access external services.

## Main API

- `ScheduleFileStore.loadTemplate(defaults:)`, `saveTemplate(_:)`, `readDaily(dateString:now:calendar:)`, `writeDaily(_:dateString:now:calendar:)`, `readState()`, and `saveState(_:)`.
- `CharacterScheduleService.generateDaily(options:)` to reuse, generate, parse, or fall back to a daily schedule.
- `CharacterScheduleService.resolveToday(options:shouldGenerate:)` to load the template, ensure a daily schedule exists, resolve and persist runtime state, and produce the conversation prompt block.
- Static helpers on `ScheduleTime` and `CharacterScheduleService` are available for callers that need to compose their own workflow.

All service methods surface persistence failures as `ScheduleServiceError` where the source would have failed while writing files. LLM and inspiration failures are intentionally treated as generation fallbacks or optional missing inspiration, respectively.