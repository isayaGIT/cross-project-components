import SwiftUI
import LineDashed

/// Renders a dashed outline along any SwiftUI `Path`.
///
/// `DashedPath` is a small, reusable component API over the lower-level LineDashed
/// renderer. It accepts arbitrary paths (not only rectangles or message bubbles) and
/// exposes the renderer's dash geometry, fill, coordinate mode, and phase controls.
public struct DashedPath: View {
    public let path: Path
    public var configuration: DashedLineConfiguration
    public var fill: DashedLineFill
    public var fillCoordinates: DashedLineFillCoordinates
    public var phase: CGFloat

    public init(
        path: Path,
        configuration: DashedLineConfiguration = .init(),
        fill: DashedLineFill = .color(.primary),
        fillCoordinates: DashedLineFillCoordinates = .pathContinuous,
        phase: CGFloat = 0
    ) {
        self.path = path
        self.configuration = configuration
        self.fill = fill
        self.fillCoordinates = fillCoordinates
        self.phase = phase.isFinite ? phase : 0
    }

    public var body: some View {
        LineDashed(
            path: path,
            configuration: configuration,
            fill: fill,
            fillCoordinates: fillCoordinates,
            phase: phase
        )
    }
}
