import SwiftUI
import Lottie
import UIKit

/// A purchasable/reusable visual theme for a message bubble. Decorations are rendered
/// separately from the bubble's shape and content, so themes never own message layout.
public struct MessageBubbleTheme {
    public enum DecorationPlacement: Sendable, Equatable {
        /// Draw inside the bubble bounds and clip to the bubble silhouette.
        case inside
        /// Draw above the fill, without clipping; useful for bows, sparkles, and mascots.
        case overlapping
    }

    public struct LottieDecoration: Identifiable {
        public let id: String
        public let animationName: String
        public var placement: DecorationPlacement
        public var size: CGSize
        public var alignment: Alignment
        public var offset: CGSize
        public var loopMode: LottieLoopMode
        public var contentMode: UIView.ContentMode

        public init(
            id: String? = nil,
            animationName: String,
            placement: DecorationPlacement = .overlapping,
            size: CGSize = CGSize(width: 44, height: 44),
            alignment: Alignment = .topTrailing,
            offset: CGSize = .zero,
            loopMode: LottieLoopMode = .loop,
            contentMode: UIView.ContentMode = .scaleAspectFit
        ) {
            self.id = id ?? animationName
            self.animationName = animationName
            self.placement = placement
            self.size = CGSize(width: max(1, size.width), height: max(1, size.height))
            self.alignment = alignment
            self.offset = offset
            self.loopMode = loopMode
            self.contentMode = contentMode
        }
    }

    public var decorations: [LottieDecoration]

    public init(decorations: [LottieDecoration] = []) {
        self.decorations = decorations
    }

    public static let `default` = MessageBubbleTheme()
}

/// Applies theme decorations in a dedicated rendering layer, separate from message content.
struct MessageBubbleDecorationLayer: View {
    var theme: MessageBubbleTheme
    var placement: MessageBubbleTheme.DecorationPlacement? = .inside

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(theme.decorations.filter { $0.placement == placement }) { decoration in
                    LottieDecorationView(decoration: decoration)
                        .frame(width: decoration.size.width, height: decoration.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: decoration.alignment)
                        .offset(decoration.offset)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct LottieDecorationView: UIViewRepresentable {
    let decoration: MessageBubbleTheme.LottieDecoration

    final class Coordinator {
        var animationName: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: decoration.animationName)
        context.coordinator.animationName = decoration.animationName
        view.contentMode = decoration.contentMode
        view.loopMode = decoration.loopMode
        view.backgroundBehavior = .pauseAndRestore
        view.isUserInteractionEnabled = false
        view.play()
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
        view.contentMode = decoration.contentMode
        view.loopMode = decoration.loopMode
        if context.coordinator.animationName != decoration.animationName {
            view.animation = LottieAnimation.named(decoration.animationName)
            context.coordinator.animationName = decoration.animationName
            view.play()
        }
    }
}
