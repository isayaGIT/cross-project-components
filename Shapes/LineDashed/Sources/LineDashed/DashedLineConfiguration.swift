import SwiftUI

/// Controls the geometry and distribution of the individual dash segments.
public struct DashedLineConfiguration: Sendable, Equatable {
    public enum ClosedPathMode: Sendable, Equatable {
        /// Adjusts the pattern period so a closed path is distributed evenly.
        case evenlyDistributed
        /// Preserves the configured dash length and gap, including at the seam.
        case fixedLengthAndSpacing
    }

    public var lineWidth: CGFloat
    public var dashLength: CGFloat
    public var dashSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var closedPathMode: ClosedPathMode

    public init(
        lineWidth: CGFloat = 2,
        dashLength: CGFloat = 8,
        dashSpacing: CGFloat = 4,
        cornerRadius: CGFloat = 1,
        closedPathMode: ClosedPathMode = .evenlyDistributed
    ) {
        self.lineWidth = Self.finitePositive(lineWidth) ? lineWidth : 0
        self.dashLength = Self.finitePositive(dashLength) ? dashLength : 0
        self.dashSpacing = dashSpacing.isFinite ? max(0, dashSpacing) : 0
        self.cornerRadius = cornerRadius.isFinite ? max(0, cornerRadius) : 0
        self.closedPathMode = closedPathMode
    }

    private static func finitePositive(_ value: CGFloat) -> Bool {
        value.isFinite && value > 0
    }
}

/// Determines whether fill coordinates continue across the path or restart for every dash.
public enum DashedLineFillCoordinates: Sendable, Equatable {
    case pathContinuous
    case perSegment
}
