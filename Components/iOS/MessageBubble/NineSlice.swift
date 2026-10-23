import Foundation
import CoreGraphics

/// The nine regions used when adapting a designed bubble animation to variable message sizes.
public enum BubbleNineSliceRegion: String, CaseIterable, Sendable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
}

/// The six operations supported by the source animation's compact six-hex-digit convention.
public enum BubbleNineSliceOperation: UInt8, Sendable, Equatable {
    case addDifference = 0
    case subtractDifference = 1
    case multiplyRatio = 2
    case addHalfDifference = 3
    case subtractHalfDifference = 4
    case adjustImageScale = 5

    public func apply(value: CGFloat, difference: CGFloat, ratio: CGFloat, sourceDimension: CGFloat) -> CGFloat {
        switch self {
        case .addDifference: return value + difference
        case .subtractDifference: return value - difference
        case .multiplyRatio: return value * ratio
        case .addHalfDifference: return value + difference / 2
        case .subtractHalfDifference: return value - difference / 2
        case .adjustImageScale:
            guard sourceDimension.isFinite, sourceDimension > 0 else { return value }
            return value + 100 * difference / sourceDimension
        }
    }
}

/// Structured representation of the legacy 24-bit encoding. Each three-bit nibble-like
/// digit is a decimal operation code; Z/Y/X are stored in that order for each of s and p.
/// Keep calculations in this typed representation rather than doing arithmetic on the packed integer.
public struct BubbleNineSliceAdjustment: Sendable, Equatable {
    public var scaleZ: BubbleNineSliceOperation
    public var scaleY: BubbleNineSliceOperation
    public var scaleX: BubbleNineSliceOperation
    public var positionZ: BubbleNineSliceOperation
    public var positionY: BubbleNineSliceOperation
    public var positionX: BubbleNineSliceOperation

    public init(
        scaleZ: BubbleNineSliceOperation = .multiplyRatio,
        scaleY: BubbleNineSliceOperation = .multiplyRatio,
        scaleX: BubbleNineSliceOperation = .multiplyRatio,
        positionZ: BubbleNineSliceOperation = .multiplyRatio,
        positionY: BubbleNineSliceOperation = .multiplyRatio,
        positionX: BubbleNineSliceOperation = .multiplyRatio
    ) {
        self.scaleZ = scaleZ
        self.scaleY = scaleY
        self.scaleX = scaleX
        self.positionZ = positionZ
        self.positionY = positionY
        self.positionX = positionX
    }

    /// Decodes six hexadecimal digits in `sssppp` order. Each digit must map to an operation (0...5).
    public init?(encoded: UInt32) {
        guard encoded <= 0xFFFFFF else { return nil }
        let digits = (0..<6).reversed().map { UInt8((encoded >> ($0 * 4)) & 0xF) }
        guard digits.allSatisfy({ $0 <= 5 }), digits.count == 6 else { return nil }
        scaleZ = BubbleNineSliceOperation(rawValue: digits[0])!
        scaleY = BubbleNineSliceOperation(rawValue: digits[1])!
        scaleX = BubbleNineSliceOperation(rawValue: digits[2])!
        positionZ = BubbleNineSliceOperation(rawValue: digits[3])!
        positionY = BubbleNineSliceOperation(rawValue: digits[4])!
        positionX = BubbleNineSliceOperation(rawValue: digits[5])!
    }

    public var encoded: UInt32 {
        let digits: [BubbleNineSliceOperation] = [scaleZ, scaleY, scaleX, positionZ, positionY, positionX]
        return digits.reduce(UInt32(0)) { ($0 << 4) | UInt32($1.rawValue) }
    }
}

/// Geometry helper for a classic nine-slice grid. Insets are preserved; only the center strips
/// and center region absorb the size delta. All dimensions are clamped to avoid inverted cells.
public struct BubbleNineSliceGrid: Sendable, Equatable {
    public let sourceSize: CGSize
    public let destinationSize: CGSize
    public let insets: EdgeInsetsValue

    public struct EdgeInsetsValue: Sendable, Equatable {
        public var top: CGFloat
        public var leading: CGFloat
        public var bottom: CGFloat
        public var trailing: CGFloat

        public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
            self.top = max(0, top)
            self.leading = max(0, leading)
            self.bottom = max(0, bottom)
            self.trailing = max(0, trailing)
        }
    }

    public init(sourceSize: CGSize, destinationSize: CGSize, insets: EdgeInsetsValue) {
        self.sourceSize = CGSize(width: max(0, sourceSize.width), height: max(0, sourceSize.height))
        self.destinationSize = CGSize(width: max(0, destinationSize.width), height: max(0, destinationSize.height))
        self.insets = insets
    }

    public func rect(for region: BubbleNineSliceRegion) -> CGRect {
        let sw = sourceSize.width, sh = sourceSize.height
        let dw = destinationSize.width, dh = destinationSize.height
        let left = min(insets.leading, min(sw, dw) / 2)
        let right = min(insets.trailing, min(sw, dw) / 2)
        let top = min(insets.top, min(sh, dh) / 2)
        let bottom = min(insets.bottom, min(sh, dh) / 2)
        let destWidths = [left, max(0, dw - left - right), right]
        let destHeights = [top, max(0, dh - top - bottom), bottom]
        let column: Int, row: Int
        switch region {
        case .topLeading: (column, row) = (0, 0)
        case .top: (column, row) = (1, 0)
        case .topTrailing: (column, row) = (2, 0)
        case .leading: (column, row) = (0, 1)
        case .center: (column, row) = (1, 1)
        case .trailing: (column, row) = (2, 1)
        case .bottomLeading: (column, row) = (0, 2)
        case .bottom: (column, row) = (1, 2)
        case .bottomTrailing: (column, row) = (2, 2)
        }
        let x = destWidths.prefix(column).reduce(0, +)
        let y = destHeights.prefix(row).reduce(0, +)
        return CGRect(x: x, y: y, width: destWidths[column], height: destHeights[row])
    }
}
