import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A standalone circular metal button using the original brushed-metal face texture.
/// The face is extracted from the supplied reference so its exact machining pattern,
/// highlight placement, and edge treatment are preserved instead of approximated.
public struct MetalCircularButton: View {
    private let diameter: CGFloat
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(
        diameter: CGFloat = 82.33,
        accessibilityLabel: String = "Metal button",
        action: @escaping () -> Void = {}
    ) {
        self.diameter = diameter.isFinite ? max(24, diameter) : 82.33
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    private var faceImage: Image {
        #if canImport(UIKit)
        Image(uiImage: MetalCircularButtonAsset.image)
        #elseif canImport(AppKit)
        Image(nsImage: MetalCircularButtonAsset.image)
        #else
        Image(systemName: "circle")
        #endif
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.30))
                    .blur(radius: diameter * 0.025)
                    .offset(x: diameter * 0.018, y: diameter * 0.030)

                faceImage
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: diameter, height: diameter)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(MetalCircularButtonPressStyle())
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(accessibilityLabel)
    }
}

private enum MetalCircularButtonAsset {
    #if SWIFT_PACKAGE
    static let bundle = Bundle.module
    #else
    static let bundle = Bundle.main
    #endif

    #if canImport(UIKit)
    static let image: UIImage = {
        guard let url = bundle.url(forResource: "MetalCircularButtonFace", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            preconditionFailure("MetalCircularButtonFace.png is missing from the component resource bundle")
        }
        return image
    }()
    #elseif canImport(AppKit)
    static let image: NSImage = {
        guard let url = bundle.url(forResource: "MetalCircularButtonFace", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("MetalCircularButtonFace.png is missing from the component resource bundle")
        }
        return image
    }()
    #endif
}

private struct MetalCircularButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Reference metal button") {
    ZStack {
        Color(red: 0.71, green: 0.71, blue: 0.71).ignoresSafeArea()
        MetalCircularButton(diameter: 82.33)
    }
}
