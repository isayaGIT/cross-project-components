import Foundation

/// Shared dimensions, typography, spacing, and motion values read from the same
/// design-tokens.json resource as ComponentDesignPalette.
public struct ComponentDesignMetrics {
    private let values: [String: Double]

    public static let warmEmber = ComponentDesignMetrics(values: ComponentDesignPalette.rawMetrics)

    private init(values: [String: Double]) {
        self.values = values
    }

    private func value(_ token: String) -> CGFloat {
        guard let value = values[token] else {
            preconditionFailure("Missing design metric token '\(token)' in design-tokens.json")
        }
        return CGFloat(value)
    }

    public var controlDiameter: CGFloat { value("controlDiameter") }
    public var defaultMaximumLines: Int { Int(value("defaultMaximumLines")) }
    public var controlBackgroundDiameter: CGFloat { value("controlBackgroundDiameter") }
    public var actionBracketDiameter: CGFloat { value("actionBracketDiameter") }
    public var barHorizontalPadding: CGFloat { value("barHorizontalPadding") }
    public var barVerticalPadding: CGFloat { value("barVerticalPadding") }
    public var buttonGap: CGFloat { value("buttonGap") }
    public var fieldHorizontalPadding: CGFloat { value("fieldHorizontalPadding") }
    public var fieldVerticalPadding: CGFloat { value("fieldVerticalPadding") }
    public var fieldCornerRadius: CGFloat { value("fieldCornerRadius") }
    public var separatorThickness: CGFloat { value("separatorThickness") }
    public var shadowRadius: CGFloat { value("shadowRadius") }
    public var shadowYOffset: CGFloat { value("shadowYOffset") }
    public var textFontSize: CGFloat { value("textFontSize") }
    public var statusFontSize: CGFloat { value("statusFontSize") }
    public var smallFontSize: CGFloat { value("smallFontSize") }
    public var actionFontSize: CGFloat { value("actionFontSize") }
    public var iconFontSize: CGFloat { value("iconFontSize") }
    public var transitionDuration: CGFloat { value("transitionDuration") }
    public var interactionDuration: CGFloat { value("interactionDuration") }
    public var pressedButtonScale: CGFloat { value("pressedButtonScale") }
    public var pressedButtonOpacity: CGFloat { value("pressedButtonOpacity") }
    public var pressedFieldScale: CGFloat { value("pressedFieldScale") }
    public var pressedActionScale: CGFloat { value("pressedActionScale") }
    public var restingScale: CGFloat { value("restingScale") }
    public var fullOpacity: CGFloat { value("fullOpacity") }
    public var longPressMinimumDuration: Double { Double(value("longPressMinimumDuration")) }
    public var longPressMaximumDistance: CGFloat { value("longPressMaximumDistance") }
    public var actionButtonHorizontalPadding: CGFloat { value("actionButtonHorizontalPadding") }
    public var actionButtonBottomPadding: CGFloat { value("actionButtonBottomPadding") }
    public var actionButtonVerticalGap: CGFloat { value("actionButtonVerticalGap") }
    public var actionButtonAdditionalOffset: CGFloat { value("actionButtonAdditionalOffset") }
    public var errorBannerHorizontalPadding: CGFloat { value("errorBannerHorizontalPadding") }
    public var errorBannerVerticalPadding: CGFloat { value("errorBannerVerticalPadding") }
    public var errorBannerBottomPadding: CGFloat { value("errorBannerBottomPadding") }
    public var statusSpacing: CGFloat { value("statusSpacing") }
    public var statusLeadingPadding: CGFloat { value("statusLeadingPadding") }
}
