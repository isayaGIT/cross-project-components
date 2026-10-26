import SwiftUI

/// Wraps arbitrary SwiftUI content in a cut-out sticker treatment.
///
/// The outline is built from offset copies of the content, so SF Symbols and
/// template artwork follow their silhouette. Pass a playing SwiftUI view to
/// support animated artwork without rasterizing it.
public struct SimulatedSticker<Content: View>: View {
    private let content: Content
    private let outlineColor: Color
    private let outlineWidth: CGFloat
    private let reliefStrength: CGFloat
    private let highlightOpacity: CGFloat
    private let shadowOpacity: CGFloat
    private let rotationRange: ClosedRange<Double>
    private let allowsRotation: Bool
    private let allowsDragging: Bool
    private let backToOriginal: Bool
    private let dragShadowScale: CGFloat
    private let dragShadowBlur: CGFloat
    private let onTap: (() -> Void)?

    @State private var restingRotation: Double
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragStartOffset: CGSize = .zero


    public init(
        outlineColor: Color = .white,
        outlineWidth: CGFloat = 3,
        reliefStrength: CGFloat = 1,
        highlightOpacity: CGFloat = 0.42,
        shadowOpacity: CGFloat = 0.22,
        rotationRange: ClosedRange<Double> = -2.5...2.5,
        allowsRotation: Bool = true,
        allowsDragging: Bool = true,
        backToOriginal: Bool = false,
        dragShadowScale: CGFloat = 1.65,
        dragShadowBlur: CGFloat = 1.8,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth.isFinite ? max(0, outlineWidth) : 3
        self.reliefStrength = reliefStrength.isFinite ? min(3, max(0, reliefStrength)) : 1
        self.highlightOpacity = highlightOpacity.isFinite ? min(1, max(0, highlightOpacity)) : 0.42
        self.shadowOpacity = shadowOpacity.isFinite ? min(1, max(0, shadowOpacity)) : 0.22
        self.rotationRange = rotationRange
        self.allowsRotation = allowsRotation
        self.allowsDragging = allowsDragging
        self.backToOriginal = backToOriginal
        self.dragShadowScale = dragShadowScale.isFinite ? max(1, dragShadowScale) : 1.65
        self.dragShadowBlur = dragShadowBlur.isFinite ? max(0, dragShadowBlur) : 1.8
        self.onTap = onTap
        _restingRotation = State(initialValue: Double.random(in: rotationRange))
    }

    public var body: some View {
        stickerArtwork
            .rotationEffect(.degrees(allowsRotation ? restingRotation : 0))
            .offset(dragOffset)
            // Lift the actively dragged sticker above neighboring cell content.
            // Static stickers keep their normal stacking order.
            .zIndex(isDragging ? 1000 : 0)
            .shadow(color: .black.opacity(shadowOpacity * (isDragging ? 0.72 : 1)), radius: 2.2 * reliefStrength * (isDragging ? dragShadowScale : 1), x: 0, y: 1.5 * reliefStrength * (isDragging ? dragShadowScale : 1))
            .shadow(color: .black.opacity(shadowOpacity * 0.28), radius: 1.4 * reliefStrength * (isDragging ? dragShadowScale * dragShadowBlur : 1), x: 0, y: 2.5 * reliefStrength * (isDragging ? dragShadowScale : 1))
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .simultaneousGesture(dragGesture)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isDragging)
            .accessibilityElement(children: .contain)
    }

    private var stickerArtwork: some View {
        ZStack {
            // Eight directional copies create a silhouette-following cut-paper edge.
            if outlineWidth > 0 {
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) * .pi / 4
                    content
                        .foregroundStyle(outlineColor)
                        .offset(x: CGFloat(cos(angle)) * outlineWidth,
                                y: CGFloat(sin(angle)) * outlineWidth)
                }
            }

            content
                .overlay {
                    // Paired, restrained highlights mimic a softly raised material.
                    content
                        .foregroundStyle(.white.opacity(highlightOpacity * reliefStrength))
                        .offset(x: -0.45 * reliefStrength, y: -0.55 * reliefStrength)
                        .mask(content)
                }
                .overlay {
                    content
                        .foregroundStyle(.black.opacity(0.10 * reliefStrength))
                        .offset(x: 0.45 * reliefStrength, y: 0.65 * reliefStrength)
                        .mask(content)
                }
        }
        .compositingGroup()
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard allowsDragging else { return }
                isDragging = true
                dragOffset = CGSize(width: dragStartOffset.width + value.translation.width,
                                    height: dragStartOffset.height + value.translation.height)
            }
            .onEnded { _ in
                guard allowsDragging else { return }
                if backToOriginal {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                        dragOffset = .zero
                        dragStartOffset = .zero
                    }
                } else {
                    // Keep the dropped position so the sticker can be freely placed.
                    dragStartOffset = dragOffset
                }
                isDragging = false
            }
    }
}
