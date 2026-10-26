import SwiftUI

/// Default product motion language for BottomSheet.
///
/// Tune these values here rather than changing animation modifiers at each call site.
public struct StandardBottomSheetMotionConfig: BottomSheetMotionConfigProtocol {
    public let sheetAnimation: Animation
    public let backdropAnimation: Animation

    public init(
        sheetAnimation: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.88),
        backdropAnimation: Animation = .easeInOut(duration: 0.22)
    ) {
        self.sheetAnimation = sheetAnimation
        self.backdropAnimation = backdropAnimation
    }

    public static let standard = StandardBottomSheetMotionConfig()
}
