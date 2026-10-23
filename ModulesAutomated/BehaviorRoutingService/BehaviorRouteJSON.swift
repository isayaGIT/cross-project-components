import Foundation
import CoreFoundation

/// Internal JSON compatibility helpers for matching the source Python service's
/// `str(value or fallback)` and `float(value)` normalization behavior.
enum BehaviorRouteJSON {
    static func decodeObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let object = value as? [String: Any] else {
            return nil
        }
        return object
    }

    /// Implements Python truthiness for JSON-compatible values before string conversion.
    static func pythonString(_ value: Any?, fallback: String) -> String {
        guard let value, !isNull(value), isTruthy(value) else { return fallback }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : "False"
            }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + array.map(pythonRepr).joined(separator: ", ") + "]"
        }
        if let object = value as? [String: Any] {
            let entries = object.keys.sorted().map { key in
                "'\(key.replacingOccurrences(of: "'", with: "\\'"))': \(pythonRepr(object[key]!))"
            }
            return "{" + entries.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }

    /// Converts JSON numbers, booleans, and numeric strings using Python-like float rules.
    /// The caller applies the source's `max(0, min(1, value))` clamp afterward.
    static func pythonFloat(_ value: Any?) -> Double? {
        guard let value, !isNull(value) else { return nil }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        switch trimmed.lowercased() {
        case "nan", "+nan", "-nan": return .nan
        case "inf", "+inf", "infinity", "+infinity": return .infinity
        case "-inf", "-infinity": return -.infinity
        default: return Double(trimmed)
        }
    }

    private static func isNull(_ value: Any) -> Bool {
        value is NSNull
    }

    private static func isTruthy(_ value: Any) -> Bool {
        if value is NSNull { return false }
        if let string = value as? String { return !string.isEmpty }
        if let number = value as? NSNumber { return number.doubleValue != 0 }
        if let array = value as? [Any] { return !array.isEmpty }
        if let object = value as? [String: Any] { return !object.isEmpty }
        return true
    }

    private static func pythonRepr(_ value: Any?) -> String {
        guard let value else { return "None" }
        if value is NSNull { return "None" }
        if let string = value as? String {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return "'\(escaped)'"
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "True" : "False"
            }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + array.map(pythonRepr).joined(separator: ", ") + "]"
        }
        if let object = value as? [String: Any] {
            let entries = object.keys.sorted().map { key in
                "'\(key)': \(pythonRepr(object[key]!))"
            }
            return "{" + entries.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }
}
