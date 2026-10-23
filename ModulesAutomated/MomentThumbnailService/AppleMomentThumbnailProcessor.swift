import Foundation
#if canImport(ImageIO) && canImport(CoreGraphics)
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Apple-platform image processor. Produces 256x256 JPEG output with a center crop,
/// gradient background, optional centered emoji overlay, and a simple text band.
public struct AppleMomentThumbnailProcessor: MomentThumbnailImageProcessor {
    public init() {}

    public func makeJPEG(moment: MomentThumbnail, gradient: ThumbnailGradient, emojiPNG: Data?, userImagesDirectory: URL?) throws -> Data? {
        if let userImagesDirectory {
            for name in moment.images where name.hasPrefix(MomentThumbnailConstants.userImagePrefix) {
                let url = userImagesDirectory.appendingPathComponent(name, isDirectory: false).standardizedFileURL
                guard url.deletingLastPathComponent() == userImagesDirectory.standardizedFileURL else { continue }
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                guard let image = Self.loadImage(url: url) else { continue }
                guard let cropped = Self.centerCrop(image, size: MomentThumbnailConstants.size),
                      let jpeg = Self.encodeJPEG(cropped, quality: 0.82) else {
                    throw MomentThumbnailError.imageProcessing("Could not crop or encode source image.")
                }
                return jpeg
            }
        }

        guard let canvas = Self.makeCanvas(size: MomentThumbnailConstants.size, gradient: gradient, emojiPNG: emojiPNG, text: moment.text, showText: emojiPNG == nil && !moment.images.contains(where: { $0.hasPrefix(MomentThumbnailConstants.userImagePrefix) })) else {
            return nil
        }
        guard let jpeg = Self.encodeJPEG(canvas, quality: 0.82) else {
            throw MomentThumbnailError.imageProcessing("Could not encode generated thumbnail as JPEG.")
        }
        return jpeg
    }

    private static func loadImage(url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func centerCrop(_ image: CGImage, size: Int) -> CGImage? {
        let side = min(image.width, image.height)
        guard side > 0 else { return nil }
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        guard let cropped = image.cropping(to: rect),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }

    private static func makeCanvas(size: Int, gradient: ThumbnailGradient, emojiPNG: Data?, text: String, showText: Bool) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bottom = CGColor(red: CGFloat(gradient.start.red) / 255, green: CGFloat(gradient.start.green) / 255, blue: CGFloat(gradient.start.blue) / 255, alpha: 1)
        let top = CGColor(red: CGFloat(gradient.end.red) / 255, green: CGFloat(gradient.end.green) / 255, blue: CGFloat(gradient.end.blue) / 255, alpha: 1)
        if let colors = CGGradient(colorsSpace: colorSpace, colors: [bottom, top] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(colors, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
        }

        if let emojiPNG, let provider = CGDataProvider(data: emojiPNG as CFData), let icon = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            let iconSide = 120
            let rect = CGRect(x: (size - iconSide) / 2, y: (size - iconSide) / 2 + 8, width: iconSide, height: iconSide)
            context.saveGState()
            context.clip(to: rect, mask: icon)
            context.draw(icon, in: rect)
            context.restoreGState()
        } else if showText {
            let compact = String(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ").prefix(10))
            if !compact.isEmpty {
                context.setFillColor(CGColor(gray: 0, alpha: 0.43))
                context.fill(CGRect(x: 0, y: 0, width: size, height: 44))
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: Self.font(size: 20),
                    .foregroundColor: CGColor(gray: 1, alpha: 0.9)
                ]
                let attributed = CFAttributedStringCreate(nil, String(compact) as CFString, attributes as CFDictionary)!
                let line = CTLineCreateWithAttributedString(attributed)
                context.textPosition = CGPoint(x: 12, y: 12)
                CTLineDraw(line, context)
            }
        }
        return context.makeImage()
    }

    private static func font(size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
#else
/// The service uses its dependency-free PNG fallback when ImageIO is unavailable.
public struct AppleMomentThumbnailProcessor: MomentThumbnailImageProcessor {
    public init() {}
    public func makeJPEG(moment: MomentThumbnail, gradient: ThumbnailGradient, emojiPNG: Data?, userImagesDirectory: URL?) throws -> Data? { nil }
}
#endif
