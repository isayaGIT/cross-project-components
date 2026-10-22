import SwiftUI

/// Reusable background content for custom components and sheets.
public struct Background: View {
    public enum Style {
        case color(ColorCustom)
        case material(Material)
        case image(Image, contentMode: ContentMode = .fill)
        case remoteImage(URL, contentMode: ContentMode = .fill)
    }

    private let style: Style

    public init(color: Color) { self.style = .color(ColorCustom(color)) }
    public init(color: ColorCustom) { self.style = .color(color) }
    public init(material: Material) { self.style = .material(material) }
    public init(image: Image, contentMode: ContentMode = .fill) { self.style = .image(image, contentMode: contentMode) }
    public init(remoteImage url: URL, contentMode: ContentMode = .fill) { self.style = .remoteImage(url, contentMode: contentMode) }

    @ViewBuilder public var body: some View {
        switch style {
        case .color(let color): color
        case .material(let material): Rectangle().fill(material)
        case .image(let image, let contentMode): image.resizable().aspectRatio(contentMode: contentMode)
        case .remoteImage(let url, let contentMode):
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: contentMode) }
                else { Rectangle().fill(.clear) }
            }
        }
    }
}
