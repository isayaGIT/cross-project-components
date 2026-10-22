import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A lightweight avatar presentation component.
///
/// `Avatar` only renders an image supplied by its caller. Image fetching,
/// caching, persistence, and retry policy belong to the caller or an image
/// loading module. Pass `nil` while no image is available to show a placeholder.
public struct Avatar: View {
    public enum Shape: Sendable {
        case circle
        case roundedRectangle(cornerRadius: CGFloat)
        case square
    }

    public enum Scaling: Sendable {
        case fill
        case fit
    }

    /// Palette used by the built-in empty-avatar silhouette.
    /// Both colors are caller-controlled so the placeholder follows app themes.
    public struct PlaceholderStyle {
        public var background: Color
        public var foreground: Color

        public init(background: Color, foreground: Color) {
            self.background = background
            self.foreground = foreground
        }

        public static let `default` = PlaceholderStyle(
            background: Color.secondary.opacity(0.16),
            foreground: Color.secondary.opacity(0.8)
        )
    }

    private let image: Image?
    private let width: CGFloat
    private let height: CGFloat
    private let shape: Shape
    private let contentMode: ContentMode
    private let placeholder: Image?
    private let placeholderStyle: PlaceholderStyle
    private let pokeEnabled: Bool
    private let vibration: CGFloat
    @State private var pokeTrigger = 0

    public init(
        image: Image?,
        width: CGFloat,
        height: CGFloat,
        shape: Shape = .circle,
        scaling: Scaling = .fill,
        placeholder: Image? = nil,
        placeholderStyle: PlaceholderStyle = .default,
        pokeEnabled: Bool = false,
        vibration: CGFloat = 0
    ) {
        self.image = image
        self.width = max(0, width)
        self.height = max(0, height)
        self.shape = shape
        self.contentMode = scaling == .fill ? .fill : .fit
        self.placeholder = placeholder
        self.placeholderStyle = placeholderStyle
        self.pokeEnabled = pokeEnabled
        self.vibration = min(max(vibration, 0), 1)
    }

    public var body: some View {
        if pokeEnabled {
            renderedAvatar.accessibilityHint("Double-tap to poke this avatar")
        } else {
            renderedAvatar
        }
    }

    private var renderedAvatar: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let placeholder {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            } else {
                defaultPlaceholder
                    .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height)
        .clipShape(ResolvedAvatarShape(shape: shape))
        .modifier(PokeShakeEffect(animatableData: CGFloat(pokeTrigger)))
        .animation(.linear(duration: 0.5), value: pokeTrigger)
        .onTapGesture(count: 2) {
            guard pokeEnabled else { return }
            triggerPokeFeedback()
            pokeTrigger += 1
        }
    }

    /// Emits a system haptic on iOS when vibration is greater than zero.
    /// The intensity is clamped to 0...1; 0 disables haptics and 1 is full/default intensity.
    private func triggerPokeFeedback() {
        guard vibration > 0 else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: vibration)
        #endif
    }

    /// A vector-drawn person silhouette; no image asset or network request is needed.
    private var defaultPlaceholder: some View {
        let side = min(width, height)
        let headSize = side * 0.34
        let bodySize = CGSize(width: side * 0.62, height: side * 0.40)
        let bodyCenterY = min(height * 0.83, max(0, height - bodySize.height / 2))

        return ZStack {
            placeholderStyle.background
            Circle()
                .fill(placeholderStyle.foreground)
                .frame(width: headSize, height: headSize)
                .offset(y: -height * 0.16)
            Ellipse()
                .fill(placeholderStyle.foreground)
                .frame(width: bodySize.width, height: bodySize.height)
                .offset(y: bodyCenterY - height / 2)
        }
    }
}

private struct ResolvedAvatarShape: Shape {
    let shape: Avatar.Shape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Circle().path(in: rect)
        case let .roundedRectangle(cornerRadius):
            let radius = min(max(0, cornerRadius), min(rect.width, rect.height) / 2)
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        case .square:
            return Rectangle().path(in: rect)
        }
    }
}


/// Reproduces the short, bottom-anchored wobble used by chat-app "poke" interactions.
private struct PokeShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = sin(animatableData * 2 * .pi * 2) * 0.12
        let pivot = CGPoint(x: size.width / 2, y: size.height)
        let transform = CGAffineTransform(translationX: pivot.x, y: pivot.y)
            .rotated(by: angle)
            .translatedBy(x: -pivot.x, y: -pivot.y)
        return ProjectionTransform(transform)
    }
}
