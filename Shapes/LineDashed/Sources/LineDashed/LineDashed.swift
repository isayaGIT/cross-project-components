import SwiftUI

/// Draws independent rounded-rectangle dash segments along an arbitrary path.
public struct LineDashed: View {
    private let path: Path
    private let configuration: DashedLineConfiguration
    private let fill: DashedLineFill
    private let fillCoordinates: DashedLineFillCoordinates
    private let phase: CGFloat

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

    public init(
        rect: CGRect,
        configuration: DashedLineConfiguration = .init(),
        fill: DashedLineFill = .color(.primary),
        fillCoordinates: DashedLineFillCoordinates = .pathContinuous,
        phase: CGFloat = 0
    ) {
        self.init(path: Path(rect), configuration: configuration, fill: fill, fillCoordinates: fillCoordinates, phase: phase)
    }

    public init(
        roundedRect rect: CGRect,
        cornerRadius: CGFloat,
        configuration: DashedLineConfiguration = .init(),
        fill: DashedLineFill = .color(.primary),
        fillCoordinates: DashedLineFillCoordinates = .pathContinuous,
        phase: CGFloat = 0
    ) {
        let radius = cornerRadius.isFinite ? max(0, cornerRadius) : 0
        self.init(path: Path(roundedRect: rect, cornerRadius: radius), configuration: configuration, fill: fill, fillCoordinates: fillCoordinates, phase: phase)
    }

    public var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let segments = DashedLinePathEngine().segments(path: path, configuration: configuration, phase: phase)
            guard !segments.isEmpty else { return }
            let globalRect = path.boundingRect
            for segment in segments {
                var local = Path(roundedRect: CGRect(x: -segment.length / 2, y: -segment.width / 2, width: segment.length, height: segment.width), cornerSize: CGSize(width: segment.cornerRadius, height: segment.cornerRadius))
                var transform = CGAffineTransform(rotationAngle: segment.angle)
                transform.tx = segment.center.x
                transform.ty = segment.center.y
                local = local.applying(transform)
                switch fill {
                case .checkerboard(let cellSize, let first, let second):
                    drawCheckerboard(in: &context, clippedTo: local, globalRect: globalRect, segment: segment, cellSize: cellSize, first: first, second: second, coordinates: fillCoordinates)
                case .grid(let cellSize, let lineWidth, let color, let background):
                    drawGrid(in: &context, clippedTo: local, globalRect: globalRect, segment: segment, cellSize: cellSize, lineWidth: lineWidth, color: color, background: background, coordinates: fillCoordinates)
                default:
                    context.fill(local, with: shading(for: fill, in: globalRect, segment: segment, coordinates: fillCoordinates))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func shading(for fill: DashedLineFill, in globalRect: CGRect, segment: DashedLineSegment, coordinates: DashedLineFillCoordinates) -> GraphicsContext.Shading {
        let rect: CGRect
        switch coordinates {
        case .pathContinuous:
            rect = globalRect.isNull || globalRect.isEmpty ? CGRect(x: segment.center.x - segment.length / 2, y: segment.center.y - segment.width / 2, width: segment.length, height: segment.width) : globalRect
        case .perSegment:
            rect = CGRect(x: segment.center.x - segment.length / 2, y: segment.center.y - segment.width / 2, width: segment.length, height: segment.width)
        }
        switch fill {
        case .color(let color):
            return .color(color)
        case .linearGradient(let gradient, let start, let end):
            return .linearGradient(gradient, startPoint: point(start, in: rect), endPoint: point(end, in: rect))
        case .radialGradient(let gradient, let center, let startRadius, let endRadius):
            return .radialGradient(gradient, center: point(center, in: rect), startRadius: max(0, startRadius), endRadius: max(0, endRadius))
        case .angularGradient(let gradient, let center, let startAngle):
            return .conicGradient(gradient, center: point(center, in: rect), angle: startAngle)
        case .checkerboard, .grid:
            return .color(.clear)
        }
    }

    private func drawCheckerboard(in context: inout GraphicsContext, clippedTo path: Path, globalRect: CGRect, segment: DashedLineSegment, cellSize: CGFloat, first: Color, second: Color, coordinates: DashedLineFillCoordinates) {
        let cell = cellSize.isFinite ? max(1, cellSize) : 8
        let rect = patternRect(globalRect: globalRect, segment: segment, coordinates: coordinates)
        var layer = context
        layer.clip(to: path)
        let minX = floor(rect.minX / cell) * cell
        let minY = floor(rect.minY / cell) * cell
        var y = minY
        while y < rect.maxY {
            var x = minX
            while x < rect.maxX {
                let parity = (Int(floor(x / cell)) + Int(floor(y / cell))) & 1
                layer.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(parity == 0 ? first : second))
                x += cell
            }
            y += cell
        }
    }

    private func drawGrid(in context: inout GraphicsContext, clippedTo path: Path, globalRect: CGRect, segment: DashedLineSegment, cellSize: CGFloat, lineWidth: CGFloat, color: Color, background: Color, coordinates: DashedLineFillCoordinates) {
        let cell = cellSize.isFinite ? max(1, cellSize) : 8
        let width = lineWidth.isFinite ? max(0.5, lineWidth) : 1
        let rect = patternRect(globalRect: globalRect, segment: segment, coordinates: coordinates)
        var layer = context
        layer.clip(to: path)
        layer.fill(Path(rect), with: .color(background))
        var x = floor(rect.minX / cell) * cell
        while x <= rect.maxX {
            layer.fill(Path(CGRect(x: x - width / 2, y: rect.minY, width: width, height: rect.height)), with: .color(color))
            x += cell
        }
        var y = floor(rect.minY / cell) * cell
        while y <= rect.maxY {
            layer.fill(Path(CGRect(x: rect.minX, y: y - width / 2, width: rect.width, height: width)), with: .color(color))
            y += cell
        }
    }

    private func patternRect(globalRect: CGRect, segment: DashedLineSegment, coordinates: DashedLineFillCoordinates) -> CGRect {
        switch coordinates {
        case .pathContinuous:
            return globalRect.isNull || globalRect.isEmpty ? CGRect(x: segment.center.x - segment.length / 2, y: segment.center.y - segment.width / 2, width: segment.length, height: segment.width) : globalRect
        case .perSegment:
            return CGRect(x: segment.center.x - segment.length / 2, y: segment.center.y - segment.width / 2, width: segment.length, height: segment.width)
        }
    }

    private func point(_ unitPoint: UnitPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * unitPoint.x, y: rect.minY + rect.height * unitPoint.y)
    }
}
