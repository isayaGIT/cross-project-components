import Foundation

/// Source-compatible token cost estimation. Rates are USD per million tokens.
public enum LLMCostAccounting {
    public struct PriceRule: Sendable, Equatable {
        public let modelSubstring: String
        public let dollarsPerMillionTokens: Double
        public init(modelSubstring: String, dollarsPerMillionTokens: Double) {
            self.modelSubstring = modelSubstring
            self.dollarsPerMillionTokens = dollarsPerMillionTokens
        }
    }

    /// Order is significant: the first case-insensitive substring match wins.
    public static let priceRules: [PriceRule] = [
        .init(modelSubstring: "deepseek-v4-flash", dollarsPerMillionTokens: 0.14),
        .init(modelSubstring: "deepseek-chat", dollarsPerMillionTokens: 0.27),
        .init(modelSubstring: "deepseek-reasoner", dollarsPerMillionTokens: 0.55),
        .init(modelSubstring: "deepseek", dollarsPerMillionTokens: 0.27),
        .init(modelSubstring: "deepseek-ai/DeepSeek-V3", dollarsPerMillionTokens: 0.27),
        .init(modelSubstring: "deepseek-ai/DeepSeek-V3.2", dollarsPerMillionTokens: 0.27),
        .init(modelSubstring: "deepseek-ai", dollarsPerMillionTokens: 0.27),
        .init(modelSubstring: "claude-opus", dollarsPerMillionTokens: 15.0),
        .init(modelSubstring: "claude-sonnet", dollarsPerMillionTokens: 3.0),
        .init(modelSubstring: "claude-haiku", dollarsPerMillionTokens: 0.8),
        .init(modelSubstring: "claude", dollarsPerMillionTokens: 3.0)
    ]
    public static let defaultDollarsPerMillionTokens = 0.27

    public static func rate(for model: String?) -> Double {
        let name = (model ?? "").lowercased()
        return priceRules.first(where: { name.contains($0.modelSubstring.lowercased()) })?.dollarsPerMillionTokens ?? defaultDollarsPerMillionTokens
    }

    /// Matches the original estimator: both token classes use one model-level rate.
    public static func estimateCost(model: String?, promptTokens: Any?, completionTokens: Any?) -> Double {
        let total = integer(promptTokens) + integer(completionTokens)
        guard total > 0 else { return 0 }
        return Double(total) * rate(for: model) / 1_000_000
    }

    private static func integer(_ value: Any?) -> Int {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let number = Int(string) { return number }
        return 0
    }
}
