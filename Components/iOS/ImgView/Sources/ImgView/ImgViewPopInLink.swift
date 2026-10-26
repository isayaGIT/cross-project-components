import SwiftUI
import Animated

/// Opens ImgView from a caller-provided thumbnail using PopInTransition.
/// Source geometry, presentation state, and reverse dismissal are encapsulated here.
public struct ImgViewPopInLink<Source: View>: View {
    private let images: [ImgViewImage]
    private let initialIndex: Int
    private let sourceID: String
    private let speed: Double
    private let sourceCornerRadius: CGFloat
    private let destinationCornerRadius: CGFloat
    private let source: Source

    @State private var isPresented = false

    public init(
        images: [ImgViewImage],
        initialIndex: Int = 0,
        sourceID: String = "img-view-pop-in-source",
        speed: Double = 1,
        sourceCornerRadius: CGFloat = 18,
        destinationCornerRadius: CGFloat = 0,
        @ViewBuilder source: () -> Source
    ) {
        self.images = images
        self.initialIndex = initialIndex
        self.sourceID = sourceID
        self.speed = max(0.1, speed)
        self.sourceCornerRadius = max(0, sourceCornerRadius)
        self.destinationCornerRadius = max(0, destinationCornerRadius)
        self.source = source()
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            source
                .popInSource(id: sourceID)
                .opacity(isPresented ? 0 : 1)
        }
        .buttonStyle(.plain)
        .popInTransition(
            isPresented: $isPresented,
            id: sourceID,
            speed: speed,
            destinationAspectRatio: nil,
            sourceCornerRadius: sourceCornerRadius,
            destinationCornerRadius: destinationCornerRadius,
            backdropOpacity: 0.2,
            backdropBlurOpacity: 0.42,
            contentRevealStart: 0.18,
            contentRevealEnd: 0.64
        ) {
            ImgView(isPresented: $isPresented, images: images, initialIndex: initialIndex)
        }
    }
}
