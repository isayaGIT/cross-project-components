import SwiftUI
import NukeUI

/// A lightweight thumbnail view. Remote images use NukeUI's shared pipeline;
/// local SwiftUI images are rendered directly without creating another cache.
public struct ImgThumbnail: View {
    public enum Source {
        case remote(URL)
        case local(Image)
    }

    public enum ShapeStyle {
        /// A plain rectangle, with no corner rounding.
        case rectangle
        /// A continuous, smoothly rounded rectangle using `RoundedRectSmoothed`.
        case roundedRectangle(cornerRadius: CGFloat)
        /// A centered square crop, sized to the smaller of the requested dimensions.
        case square
        /// A centered square crop clipped to a circle.
        case circle
    }

    private let source: Source
    private let size: CGSize
    private let shape: ShapeStyle
    private let placeholder: Image
    private let showsLoadingIndicator: Bool

    public init(
        source: Source,
        size: CGSize,
        shape: ShapeStyle = .roundedRectangle(cornerRadius: 12),
        placeholder: Image = Image(systemName: "photo"),
        showsLoadingIndicator: Bool = true
    ) {
        self.source = source
        self.size = CGSize(width: max(0, size.width), height: max(0, size.height))
        self.shape = shape
        self.placeholder = placeholder
        self.showsLoadingIndicator = showsLoadingIndicator
    }

    public init(
        url: URL,
        size: CGSize,
        shape: ShapeStyle = .roundedRectangle(cornerRadius: 12),
        placeholder: Image = Image(systemName: "photo"),
        showsLoadingIndicator: Bool = true
    ) {
        self.init(source: .remote(url), size: size, shape: shape, placeholder: placeholder, showsLoadingIndicator: showsLoadingIndicator)
    }

    public init(
        image: Image,
        size: CGSize,
        shape: ShapeStyle = .roundedRectangle(cornerRadius: 12)
    ) {
        self.init(source: .local(image), size: size, shape: shape, showsLoadingIndicator: false)
    }

    private var displaySize: CGSize {
        switch shape {
        case .square, .circle:
            let side = min(size.width, size.height)
            return CGSize(width: side, height: side)
        case .rectangle, .roundedRectangle:
            return size
        }
    }

    public var body: some View {
        imageContent
            .frame(width: displaySize.width, height: displaySize.height)
            .clipped()
            .clipShape(clipShape)
            .accessibilityLabel("Image thumbnail")
    }

    @ViewBuilder
    private var imageContent: some View {
        switch source {
        case .local(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .remote(let url):
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    placeholderContent
                } else {
                    ZStack {
                        placeholderBackground
                        if showsLoadingIndicator {
                            ProgressView().controlSize(.small)
                        } else {
                            placeholder
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            placeholderBackground
            placeholder
                .resizable()
                .scaledToFit()
                .padding(8)
                .foregroundStyle(.secondary)
        }
    }

    private var placeholderBackground: some View {
        Rectangle().fill(Color.primary.opacity(0.06))
    }

    private var clipShape: AnyShape {
        switch shape {
        case .rectangle, .square:
            AnyShape(Rectangle())
        case .roundedRectangle(let radius):
            AnyShape(RoundedRectSmoothed(cornerRadius: min(max(0, radius), min(displaySize.width, displaySize.height) / 2)))
        case .circle:
            AnyShape(Circle())
        }
    }
}
