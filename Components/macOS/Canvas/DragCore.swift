import CoreGraphics

/// Deterministic drag math shared by canvas nodes, handles, and timeline markers.
/// Callers capture the starting model value once, then derive every update from the
/// gesture's cumulative translation. Never use the previous update as the next start.
public enum DragCore {
    /// Converts cumulative gesture translations into an incremental delta for APIs
    /// whose callbacks intentionally consume per-event changes (resize/rotate handles).
    public static func incrementalDelta(from previous: CGSize, to current: CGSize) -> CGSize {
        CGSize(width: current.width - previous.width,
               height: current.height - previous.height)
    }

    /// Applies a gesture translation to a model-space point, accounting for canvas zoom.
    public static func translated(_ start: CGPoint, by translation: CGSize, scale: CGFloat = 1) -> CGPoint {
        let safeScale = max(abs(scale), 0.0001)
        return CGPoint(
            x: start.x + translation.width / safeScale,
            y: start.y + translation.height / safeScale
        )
    }

    /// Maps horizontal pointer movement onto a timeline's visible time range.
    public static func translated(_ start: Double, horizontalTranslation: CGFloat, trackWidth: CGFloat, visibleUnits: Double) -> Double {
        start + Double(horizontalTranslation / max(trackWidth, 1)) * visibleUnits
    }

    public static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
