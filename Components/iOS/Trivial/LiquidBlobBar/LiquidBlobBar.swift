import SwiftUI

/// A horizontal composition whose neighboring views can visually flow into one another.
///
/// LiquidBlobBar does not add a background, tint, shape, or material. It creates a blurred
/// copy of the caller's content, thresholds that copy's alpha into a shared liquid silhouette,
/// and draws the original content sharply above it. The original views retain their own
/// appearance, accessibility, and hit-testing behavior.
public struct LiquidBlobBar<Content: View>: View {
    private let spacing: CGFloat
    private let fusionRadius: CGFloat
    private let fusionStrength: Double
    private let fusionThreshold: Float
    private let edgeSoftness: Float
    private let alignment: VerticalAlignment
    private let content: Content

    /// Creates a reusable liquid-blob horizontal layout.
    ///
    /// - Parameters:
    ///   - spacing: Equal spacing between adjacent children. Smaller values make the liquid
    ///     silhouette bridge the gap more readily.
    ///   - fusionRadius: Blur radius applied only to the decorative fusion layer.
    ///   - fusionStrength: Opacity of the fusion layer, from 0 (off) to 1 (full strength).
    ///   - fusionThreshold: Alpha threshold for joining nearby surfaces. Lower values merge
    ///     more readily; higher values keep the silhouette tighter.
    ///   - edgeSoftness: Width of the smoothed edge around the threshold.
    ///   - alignment: Vertical alignment of children.
    ///   - content: Any number of caller-owned SwiftUI views.
    public init(
        spacing: CGFloat = 4,
        fusionRadius: CGFloat = 8,
        fusionStrength: Double = 0.9,
        fusionThreshold: Float = 0.16,
        edgeSoftness: Float = 0.12,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = Self.clamp(spacing, lowerBound: 0, upperBound: 80, fallback: 4)
        self.fusionRadius = Self.clamp(fusionRadius, lowerBound: 0, upperBound: 40, fallback: 8)
        self.fusionStrength = min(1, max(0, fusionStrength.isFinite ? fusionStrength : 0.9))
        self.fusionThreshold = Self.clamp(fusionThreshold, lowerBound: 0.001, upperBound: 0.99, fallback: 0.16)
        self.edgeSoftness = Self.clamp(edgeSoftness, lowerBound: 0.001, upperBound: 0.5, fallback: 0.12)
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: alignment)) {
            row
                .compositingGroup()
                .blur(radius: fusionRadius)
                .layerEffect(
                    Self.fusionShader(threshold: fusionThreshold, softness: edgeSoftness),
                    maxSampleOffset: .zero
                )
                .opacity(fusionStrength)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            row
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var row: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
    }


    private static func fusionShader(threshold: Float, softness: Float) -> Shader {
        #if SWIFT_PACKAGE
        #if targetEnvironment(simulator)
        let libraryName = "LiquidBlobBar-simulator"
        #else
        let libraryName = "LiquidBlobBar-device"
        #endif
        guard let url = Bundle.module.url(forResource: libraryName, withExtension: "metallib") else {
            preconditionFailure("LiquidBlobBar Metal shader resource is missing: \(libraryName).metallib")
        }
        return ShaderLibrary(url: url).liquidBlobAlphaThreshold(
            .float(threshold),
            .float(softness)
        )
        #else
        return ShaderLibrary.liquidBlobAlphaThreshold(
            .float(threshold),
            .float(softness)
        )
        #endif
    }

    private static func clamp(
        _ value: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        guard value.isFinite else { return fallback }
        return min(upperBound, max(lowerBound, value))
    }

    private static func clamp(
        _ value: Float,
        lowerBound: Float,
        upperBound: Float,
        fallback: Float
    ) -> Float {
        guard value.isFinite else { return fallback }
        return min(upperBound, max(lowerBound, value))
    }
}
