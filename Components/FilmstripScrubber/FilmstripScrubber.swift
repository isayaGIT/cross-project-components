import SwiftUI
import AppKit

/// Standalone data model; the host application does not need to expose its own model type.
public struct FilmstripItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let imageURL: URL
    public init(id: String, title: String, imageURL: URL) { self.id = id; self.title = title; self.imageURL = imageURL }
}

/// Pixel-continuous geometry shared by rendering and selection.
public enum FilmstripMetrics {
    public static func contentWidth(itemCount: Int, frameWidth: CGFloat, gap: CGFloat) -> CGFloat {
        guard itemCount > 0 else { return 0 }; return CGFloat(itemCount) * frameWidth + CGFloat(max(0, itemCount - 1)) * gap
    }
    public static func maxScrollOffset(width: CGFloat, itemCount: Int, frameWidth: CGFloat, gap: CGFloat) -> CGFloat {
        max(0, contentWidth(itemCount: itemCount, frameWidth: frameWidth, gap: gap) - max(0, width))
    }
    public static func scrollOffset(progress: CGFloat, width: CGFloat, itemCount: Int, frameWidth: CGFloat, gap: CGFloat) -> CGFloat {
        min(max(progress, 0), 1) * maxScrollOffset(width: width, itemCount: itemCount, frameWidth: frameWidth, gap: gap)
    }
    public static func firstVisibleIndex(scrollOffset: CGFloat, frameWidth: CGFloat, gap: CGFloat, itemCount: Int) -> Int {
        guard itemCount > 0, frameWidth + gap > 0 else { return 0 }
        return min(max(Int(floor(max(0, scrollOffset) / (frameWidth + gap))), 0), itemCount - 1)
    }
    public static func partialFrameOffset(scrollOffset: CGFloat, frameWidth: CGFloat, gap: CGFloat) -> CGFloat {
        let step = frameWidth + gap; guard step > 0 else { return 0 }
        let offset = max(0, scrollOffset); return offset - floor(offset / step) * step
    }
    public static func visibleCount(width: CGFloat, frameWidth: CGFloat, gap: CGFloat, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }; let step = frameWidth + gap
        guard width > 0, step > 0 else { return 1 }; return min(itemCount, max(1, Int(floor((width + gap) / step))))
    }
    public static func selectedIndex(contentX: CGFloat, itemCount: Int, frameWidth: CGFloat, gap: CGFloat) -> Int {
        guard itemCount > 0, frameWidth + gap > 0 else { return 0 }
        let nearest = Int(((contentX - frameWidth / 2) / (frameWidth + gap)).rounded())
        return min(max(nearest, 0), itemCount - 1)
    }
}

/// An image filmstrip that doubles as its own continuous scrubber.
public struct FilmstripScrubber: View {
    public let items: [FilmstripItem]
    public var frameWidth: CGFloat
    public var frameGap: CGFloat
    public var onSelectionChanged: ((FilmstripItem, Int) -> Void)?
    @State private var pointerProgress: CGFloat = 0
    @State private var isScrubbing = false

    public init(items: [FilmstripItem], frameWidth: CGFloat = 54, frameGap: CGFloat = 3, onSelectionChanged: ((FilmstripItem, Int) -> Void)? = nil) {
        self.items = items; self.frameWidth = max(1, frameWidth); self.frameGap = max(0, frameGap); self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, count = items.count
            let offset = FilmstripMetrics.scrollOffset(progress: pointerProgress, width: width, itemCount: count, frameWidth: frameWidth, gap: frameGap)
            let start = FilmstripMetrics.firstVisibleIndex(scrollOffset: offset, frameWidth: frameWidth, gap: frameGap, itemCount: count)
            let visible = FilmstripMetrics.visibleCount(width: width, frameWidth: frameWidth, gap: frameGap, itemCount: count)
            let end = min(count, start + visible + 2), pointerX = pointerProgress * width
            let selected = FilmstripMetrics.selectedIndex(contentX: pointerX + offset, itemCount: count, frameWidth: frameWidth, gap: frameGap)
            HStack(spacing: frameGap) {
                if count > 0 { ForEach(start..<end, id: \.self) { index in thumbnail(items[index], index: index, selected: index == selected).frame(width: frameWidth, height: max(0, geometry.size.height - 6)) } }
            }
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: -FilmstripMetrics.partialFrameOffset(scrollOffset: offset, frameWidth: frameWidth, gap: frameGap))
            .frame(width: width, height: geometry.size.height, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            // Stroke after clipping so the viewport border remains intact at every scroll position.
            .overlay { RoundedRectangle(cornerRadius: 6).stroke(isScrubbing ? Color.accentColor : Color.primary.opacity(0.14), lineWidth: isScrubbing ? 2 : 1).allowsHitTesting(false) }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged { value in
                isScrubbing = true
                guard count > 0, width > 0 else { pointerProgress = 0; return }
                let progress = min(max(value.location.x / width, 0), 1)
                pointerProgress = progress
                let liveOffset = FilmstripMetrics.scrollOffset(progress: progress, width: width, itemCount: count, frameWidth: frameWidth, gap: frameGap)
                let liveIndex = FilmstripMetrics.selectedIndex(contentX: progress * width + liveOffset, itemCount: count, frameWidth: frameWidth, gap: frameGap)
                onSelectionChanged?(items[liveIndex], liveIndex)
            }.onEnded { _ in isScrubbing = false })
            .accessibilityElement().accessibilityLabel("Image filmstrip")
            .accessibilityValue(count == 0 ? "No images" : "Image \(selected + 1) of \(count)")
            .help("Click or drag across the filmstrip to browse all images")
        }
    }

    @ViewBuilder private func thumbnail(_ item: FilmstripItem, index: Int, selected: Bool) -> some View {
        ZStack {
            if let image = NSImage(contentsOf: item.imageURL) { Image(nsImage: image).resizable().scaledToFill() }
            else {
                RoundedRectangle(cornerRadius: 4).fill(Color(hue: Double((index * 37) % 360) / 360, saturation: 0.22, brightness: 0.84))
                Image(systemName: "photo").font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.45))
            }
            if selected { RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2.5) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(alignment: .bottomLeading) { Text("\(index + 1)").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundStyle(.black.opacity(0.65)).padding(3) }
        .accessibilityLabel(item.title)
    }
}
