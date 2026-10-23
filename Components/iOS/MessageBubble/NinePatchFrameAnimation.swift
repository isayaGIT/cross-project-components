import SwiftUI
import UIKit

/// A frame-by-frame bubble animation whose PNG frames are independently nine-sliced.
/// Supply image names from the app's asset catalog or the package's resource bundle.
public struct NinePatchFrameAnimation: UIViewRepresentable {
    public var frameNames: [String]
    public var sourceSize: CGSize
    public var stretchInsets: EdgeInsets
    public var duration: TimeInterval
    /// `0` repeats forever; positive values are the number of complete plays.
    public var repeatCount: Int
    public var horizontallyMirrored: Bool
    public var contentMode: UIView.ContentMode
    public var bundle: Bundle

    public init(
        frameNames: [String],
        sourceSize: CGSize,
        stretchInsets: EdgeInsets,
        duration: TimeInterval = 1.2,
        repeatCount: Int = 0,
        horizontallyMirrored: Bool = false,
        contentMode: UIView.ContentMode = .scaleToFill,
        bundle: Bundle = .main
    ) {
        self.frameNames = frameNames
        self.sourceSize = sourceSize
        self.stretchInsets = stretchInsets
        self.duration = duration
        self.repeatCount = repeatCount
        self.horizontallyMirrored = horizontallyMirrored
        self.contentMode = contentMode
        self.bundle = bundle
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        configure(view, coordinator: context.coordinator, force: true)
        return view
    }

    public func updateUIView(_ view: UIImageView, context: Context) {
        configure(view, coordinator: context.coordinator, force: false)
    }

    public final class Coordinator {
        fileprivate var signature = ""
    }

    private func configure(_ view: UIImageView, coordinator: Coordinator, force: Bool) {
        let signature = [frameNames.joined(separator: ","),
                         "\(sourceSize.width)x\(sourceSize.height)",
                         "\(stretchInsets.top),\(stretchInsets.leading),\(stretchInsets.bottom),\(stretchInsets.trailing)",
                         "\(duration)", "\(repeatCount)", "\(horizontallyMirrored)", "\(contentMode.rawValue)",
                         "\(bundle.bundleIdentifier ?? bundle.bundlePath)"].joined(separator: "|")
        guard force || coordinator.signature != signature else { return }
        coordinator.signature = signature

        let images = frameNames.compactMap { name -> UIImage? in
            guard let image = UIImage(named: name, in: bundle, compatibleWith: nil) else { return nil }
            let sourceWidth = max(1, sourceSize.width)
            let sourceHeight = max(1, sourceSize.height)
            let scaleX = image.size.width / sourceWidth
            let scaleY = image.size.height / sourceHeight
            let capInsets = UIEdgeInsets(
                top: min(image.size.height / 2, max(0, stretchInsets.top) * scaleY),
                left: min(image.size.width / 2, max(0, stretchInsets.leading) * scaleX),
                bottom: min(image.size.height / 2, max(0, stretchInsets.bottom) * scaleY),
                right: min(image.size.width / 2, max(0, stretchInsets.trailing) * scaleX)
            )
            return image.resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
        }
        view.contentMode = contentMode
        view.transform = horizontallyMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        view.animationImages = nil
        view.stopAnimating()
        view.animationImages = images
        view.animationDuration = max(0.01, duration)
        view.animationRepeatCount = max(0, repeatCount)
        if images.count > 1 {
            view.startAnimating()
        } else if let first = images.first {
            view.image = first
        } else {
            view.image = nil
        }
    }
}
