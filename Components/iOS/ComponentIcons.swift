import SwiftUI
import UIKit

/// Shared image assets bundled with CrossProjectComponentsIOS.
/// Use these accessors instead of referencing the package's private resource bundle
/// from individual components or consuming apps.
public enum ComponentIcons {
    /// The default transparent smiley-face icon used by the input accessory button.
    /// Load the packaged PNG directly so it works as a Swift Package resource even
    /// when the image is not compiled into an asset catalog. Keep a visible fallback
    /// for stale builds or a missing resource instead of rendering an empty view.
    public static var smileyFace: Image {
        if let url = Bundle.module.url(forResource: "smily-face-transparent", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        return Image(systemName: "face.smiling")
    }
}
