import Foundation

/// Synchronous JSON file store corresponding to the original service's three
/// persistence operations. The class does not own global paths; callers inject
/// paths so it can be reused in apps, extensions, and command-line tools.
public final class ScheduleFileStore {
    public let paths: ScheduleStoragePaths
    private let fileManager: FileManager

    public init(paths: ScheduleStoragePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func loadTemplate(defaults: [String: Any] = ScheduleDefaults.template) -> [String: Any] {
        var merged = defaults
        guard let data = try? Data(contentsOf: paths.templateURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let saved = object as? [String: Any] else { return merged }
        // Source behavior is a shallow top-level merge, not recursive merging.
        for (key, value) in saved { merged[key] = value }
        return merged
    }

    public func saveTemplate(_ template: [String: Any]) throws {
        try createParentDirectory(for: paths.templateURL)
        try writeJSONObject(template, to: paths.templateURL, createParent: false)
    }

    public func dailyURL(dateString: String?, now: Date = Date(), calendar: Calendar = .current) -> URL {
        let date = ScheduleTime.safeDate(dateString, now: now, calendar: calendar)
        return paths.dailyDirectoryURL.appendingPathComponent("daily_\(date).json", isDirectory: false)
    }

    public func readDaily(dateString: String?, now: Date = Date(), calendar: Calendar = .current) -> [String: Any]? {
        let url = dailyURL(dateString: dateString, now: now, calendar: calendar)
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let daily = object as? [String: Any] else { return nil }
        return daily
    }

    @discardableResult
    public func writeDaily(_ input: [String: Any], dateString: String?, now: Date = Date(), calendar: Calendar = .current) throws -> [String: Any] {
        var daily = input
        daily["date"] = ScheduleTime.safeDate(dateString ?? ScheduleJSON.string(input["date"]), now: now, calendar: calendar)
        let url = dailyURL(dateString: ScheduleJSON.string(daily["date"]), now: now, calendar: calendar)
        try createParentDirectory(for: url)
        try writeJSONObject(daily, to: url, createParent: false)
        return daily
    }

    public func readState() -> Any? {
        guard let data = try? Data(contentsOf: paths.stateURL) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Mirrors the source's save_state behavior: it does not create a missing
    /// parent directory for the state file. Errors are surfaced to the caller.
    public func saveState(_ state: Any) throws {
        try writeJSONObject(state, to: paths.stateURL, createParent: false, allowFragments: true)
    }

    private func createParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            throw ScheduleServiceError.persistence("Cannot create \(parent.path): \(error.localizedDescription)")
        }
    }

    private func writeJSONObject(_ object: Any, to url: URL, createParent: Bool, allowFragments: Bool = false) throws {
        if createParent { try createParentDirectory(for: url) }
        do {
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys] + (allowFragments ? [.fragmentsAllowed] : [])
            let data = try JSONSerialization.data(withJSONObject: object, options: options)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ScheduleServiceError.persistence("Cannot write \(url.path): \(error.localizedDescription)")
        }
    }
}
