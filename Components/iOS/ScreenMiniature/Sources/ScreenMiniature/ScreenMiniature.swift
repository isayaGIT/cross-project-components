import SwiftUI

/// Displays a scaled, non-interactive rendering of the supplied SwiftUI content.
///
/// The content is laid out at `sourceSize` and visually scaled to fit `size`.
/// Pass the same observable model to the source screen and this miniature when
/// both presentations need to reflect the same live state.
///
/// Note: this renders the supplied view hierarchy again; it does not capture or
/// mirror an already-running UIWindow/Screen instance.
public struct ScreenMiniature<Content: View>: View {
    private let sourceSize: CGSize
    private let size: CGSize
    private let content: Content

    private var scaleFactor: CGFloat {
        guard sourceSize.width > 0, sourceSize.height > 0,
              size.width > 0, size.height > 0 else { return 1 }
        return min(size.width / sourceSize.width, size.height / sourceSize.height)
    }

    public init(
        sourceSize: CGSize,
        size: CGSize,
        @ViewBuilder content: () -> Content
    ) {
        self.sourceSize = sourceSize
        self.size = size
        self.content = content()
    }

    public var body: some View {
        content
            .frame(width: sourceSize.width, height: sourceSize.height, alignment: .topLeading)
            .scaleEffect(scaleFactor, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screen miniature preview")
    }
}
