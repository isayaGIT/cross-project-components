import Foundation

/// Compatibility helpers for the path and identifier rules in cloud/services/stickers.py.
public enum StickerCatalogPath {
    /// Mirrors `_safe_sticker_path`: stringify-like input normalization is performed by callers;
    /// this method accepts a string and applies the original path checks.
    public static func safeRelativePath(_ key: String?) -> String? {
        guard let key else { return nil }
        let normalized = key
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "/" })
        let value = String(normalized)
        guard !value.isEmpty else { return nil }
        if value.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." }) {
            return nil
        }
        return value
    }

    /// Returns a path only if it is accepted by the source-compatible identifier rule.
    public static func validatedIdentifier(_ identifier: String?) -> String? {
        safeRelativePath(identifier)
    }

    /// Checks whether a catalog path resolves beneath the configured sticker root.
    /// This is an additional filesystem containment check for callers that use paths on disk.
    public static func isContained(relativePath: String, under root: URL) -> Bool {
        guard let safe = safeRelativePath(relativePath) else { return false }
        let rootURL = root.standardizedFileURL
        let candidate = rootURL.appendingPathComponent(safe).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        return candidate.path.hasPrefix(rootPath) && candidate.path != rootURL.path
    }
}
