import SwiftUI
import Foundation

/// Shared color tokens loaded from the package's `Resources/design-tokens.json`.
/// Keep color values in the JSON resource instead of defining them in Swift views.
public struct ComponentDesignPalette {
    private struct Resource: Decodable {
        let name: String
        let version: Int
        let colors: [String: String]
        let metrics: [String: Double]
    }

    private let colors: [String: Color]
    private static let resource: Resource = loadResource()

    /// The default component palette. The JSON is decoded once per process.
    public static let warmEmber = ComponentDesignPalette(hexColors: resource.colors)

    private init(hexColors: [String: String]) {
        self.colors = hexColors.mapValues { Color(hex: $0) }
    }

    static var rawMetrics: [String: Double] { resource.metrics }

    private static func loadResource() -> Resource {
        guard let url = Bundle.module.url(forResource: "design-tokens", withExtension: "json") else {
            preconditionFailure("Missing bundled Resources/design-tokens.json in CrossProjectComponentsIOS")
        }

        do {
            let resource = try JSONDecoder().decode(Resource.self, from: Data(contentsOf: url))
            guard resource.version == 1 else {
                preconditionFailure("Unsupported design-tokens.json version: \(resource.version)")
            }
            guard !resource.name.isEmpty, !resource.colors.isEmpty else {
                preconditionFailure("design-tokens.json must define a name and at least one color")
            }
            guard !resource.metrics.isEmpty else {
                preconditionFailure("design-tokens.json must define layout metrics")
            }
            return resource
        } catch {
            preconditionFailure("Unable to load design-tokens.json: \(error)")
        }
    }

    private func color(_ token: String) -> Color {
        guard let value = colors[token] else {
            preconditionFailure("Missing design color token '\(token)' in design-tokens.json")
        }
        return value
    }

    public var canvas: Color { color("canvas") }
    public var barBackground: Color { color("barBackground") }
    public var fieldBackground: Color { color("fieldBackground") }
    public var textColor: Color { color("textColor") }
    public var secondaryTextColor: Color { color("secondaryTextColor") }
    public var placeholderColor: Color { color("placeholderColor") }
    public var borderColor: Color { color("borderColor") }
    public var accent: Color { color("accent") }
    public var dangerColor: Color { color("dangerColor") }
    public var buttonBackground: Color { color("buttonBackground") }
    public var buttonForeground: Color { color("buttonForeground") }
    public var disabledBackground: Color { color("disabledBackground") }
    public var waveformBaseColor: Color { color("waveformBaseColor") }
    public var shadowColor: Color { color("shadowColor") }
    public var actionPressedBackground: Color { color("actionPressedBackground") }
    public var actionBorderColor: Color { color("actionBorderColor") }
    public var waveformGlowColor: Color { color("waveformGlowColor") }
    public var transparent: Color { color("transparent") }

    // Shared preview tokens let component tests use the same source of truth too.
    public var previewCanvas: Color { color("previewCanvas") }
    public var previewSurface: Color { color("previewSurface") }
    public var previewText: Color { color("previewText") }
    public var previewSecondaryText: Color { color("previewSecondaryText") }
    public var previewAccentSurface: Color { color("previewAccentSurface") }
    public var previewControlSurface: Color { color("previewControlSurface") }
    public var previewControlBorder: Color { color("previewControlBorder") }
    public var previewSelectedBorder: Color { color("previewSelectedBorder") }
    public var previewPanelSurface: Color { color("previewPanelSurface") }
}

private extension Color {
    init(hex source: String) {
        let valueString = source.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = UInt64(valueString, radix: 16), valueString.count == 6 || valueString.count == 8 else {
            preconditionFailure("Invalid design token hex color: \(source)")
        }

        let red, green, blue, alpha: UInt64
        if valueString.count == 8 {
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        } else {
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
