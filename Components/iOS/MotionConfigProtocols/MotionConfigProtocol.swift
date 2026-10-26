import SwiftUI

/// Shared contract for animation settings consumed by reusable UI components.
///
/// Keep this protocol focused on behavior that can be applied consistently
/// across components. Component-specific motion requirements belong in
/// refinements such as BottomSheetMotionConfigProtocol.
public protocol MotionConfigProtocol {
    /// Animation used by the dimming layer when it appears or disappears.
    var backdropAnimation: Animation { get }
}
