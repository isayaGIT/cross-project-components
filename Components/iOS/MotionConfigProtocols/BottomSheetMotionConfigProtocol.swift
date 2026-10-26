import SwiftUI

/// Motion contract required by the shared BottomSheet presenter.
public protocol BottomSheetMotionConfigProtocol: MotionConfigProtocol {
    /// Animation used by the sheet for presentation, dismissal, and interactive
    /// position changes. The same rule is intentionally shared in both directions.
    var sheetAnimation: Animation { get }
}
