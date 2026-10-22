import SwiftUI
import CoreGraphics

struct DashedLineSegment: Sendable, Equatable {
    var center: CGPoint
    var angle: CGFloat
    var length: CGFloat
    var width: CGFloat
    var cornerRadius: CGFloat
    var distance: CGFloat
    var pathPoints: [CGPoint]
}

struct DashedLinePathEngine {
    private struct Sample {
        var point: CGPoint
        var distance: CGFloat
    }

    private let tolerance: CGFloat

    init(tolerance: CGFloat = 0.1) {
        self.tolerance = max(0.05, tolerance.isFinite ? tolerance : 0.1)
    }

    func segments(path: Path, configuration: DashedLineConfiguration, phase: CGFloat = 0) -> [DashedLineSegment] {
        guard configuration.lineWidth > 0, configuration.dashLength > 0 else { return [] }
        let samples = flatten(path.cgPath)
        guard samples.count > 1, let total = samples.last?.distance, total.isFinite, total > 0 else { return [] }
        let closed = isClosed(path.cgPath)
        let dash = configuration.dashLength
        let gap = configuration.dashSpacing
        let period = dash + gap
        guard period.isFinite, period > 0 else { return [] }

        var actualDash = dash
        var actualGap = gap
        if closed, configuration.closedPathMode == .evenlyDistributed {
            let count = max(1, Int((total / period).rounded()))
            let adjustedPeriod = total / CGFloat(count)
            actualDash = min(dash, adjustedPeriod)
            actualGap = max(0, adjustedPeriod - actualDash)
        }
        let actualPeriod = actualDash + actualGap
        guard actualPeriod > 0 else { return [] }
        let offset = phase.isFinite ? phase.truncatingRemainder(dividingBy: actualPeriod) : 0
        var start = -offset
        var result: [DashedLineSegment] = []
        var safety = 0
        while start < total && safety < 100_000 {
            let segmentStart = max(0, start)
            let segmentEnd = min(total, start + actualDash)
            if segmentEnd - segmentStart > 0.001, let a = point(at: segmentStart, samples: samples), let b = point(at: segmentEnd, samples: samples), let middle = point(at: (segmentStart + segmentEnd) / 2, samples: samples) {
                let before = point(at: max(segmentStart, (segmentStart + segmentEnd) / 2 - 0.1), samples: samples) ?? a
                let after = point(at: min(segmentEnd, (segmentStart + segmentEnd) / 2 + 0.1), samples: samples) ?? b
                let angle = atan2(after.y - before.y, after.x - before.x)
                let length = segmentEnd - segmentStart
                if length.isFinite, length > 0, angle.isFinite {
                    // Keep the original path curvature inside each dash instead of replacing
                    // every dash with a rotated straight rectangle.
                    var dashPoints = [a]
                    var low = 0
                    var high = samples.count
                    while low < high {
                        let mid = (low + high) / 2
                        if samples[mid].distance <= segmentStart { low = mid + 1 } else { high = mid }
                    }
                    var index = low
                    while index < samples.count, samples[index].distance < segmentEnd {
                        dashPoints.append(samples[index].point)
                        index += 1
                    }
                    if dashPoints.last != b { dashPoints.append(b) }
                    result.append(.init(center: middle, angle: angle, length: length, width: configuration.lineWidth, cornerRadius: min(configuration.cornerRadius, min(length, configuration.lineWidth) / 2), distance: segmentStart, pathPoints: dashPoints))
                }
            }
            start += actualPeriod
            safety += 1
        }
        return result
    }

    private func isClosed(_ path: CGPath) -> Bool {
        var closed = false
        path.applyWithBlock { pointer in
            if pointer.pointee.type == .closeSubpath { closed = true }
        }
        return closed
    }

    private func flatten(_ path: CGPath) -> [Sample] {
        var points: [CGPoint] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                subpathStart = current
                points.append(current)
            case .addLineToPoint:
                current = element.points[0]
                points.append(current)
            case .addQuadCurveToPoint:
                let end = element.points[1]
                flattenQuad(from: current, control: element.points[0], to: end, output: &points, depth: 0)
                current = end
            case .addCurveToPoint:
                let end = element.points[2]
                flattenCubic(from: current, control1: element.points[0], control2: element.points[1], to: end, output: &points, depth: 0)
                current = end
            case .closeSubpath:
                if current != subpathStart { points.append(subpathStart) }
                current = subpathStart
            @unknown default:
                break
            }
        }
        guard let first = points.first else { return [] }
        var samples = [Sample(point: first, distance: 0)]
        var distance: CGFloat = 0
        for point in points.dropFirst() {
            let previous = samples[samples.count - 1].point
            let length = hypot(point.x - previous.x, point.y - previous.y)
            guard length.isFinite else { continue }
            if length > 0.0001 {
                distance += length
                samples.append(Sample(point: point, distance: distance))
            }
        }
        return samples
    }

    private func flattenQuad(from p0: CGPoint, control p1: CGPoint, to p2: CGPoint, output: inout [CGPoint], depth: Int) {
        let deviation = distanceFromLine(p1, p0, p2)
        guard deviation > tolerance, depth < 12 else { output.append(p2); return }
        let p01 = midpoint(p0, p1), p12 = midpoint(p1, p2)
        let p012 = midpoint(p01, p12)
        flattenQuad(from: p0, control: p01, to: p012, output: &output, depth: depth + 1)
        flattenQuad(from: p012, control: p12, to: p2, output: &output, depth: depth + 1)
    }

    private func flattenCubic(from p0: CGPoint, control1 p1: CGPoint, control2 p2: CGPoint, to p3: CGPoint, output: inout [CGPoint], depth: Int) {
        let deviation = max(distanceFromLine(p1, p0, p3), distanceFromLine(p2, p0, p3))
        guard deviation > tolerance, depth < 12 else { output.append(p3); return }
        let p01 = midpoint(p0, p1), p12 = midpoint(p1, p2), p23 = midpoint(p2, p3)
        let p012 = midpoint(p01, p12), p123 = midpoint(p12, p23), p0123 = midpoint(p012, p123)
        flattenCubic(from: p0, control1: p01, control2: p012, to: p0123, output: &output, depth: depth + 1)
        flattenCubic(from: p0123, control1: p123, control2: p23, to: p3, output: &output, depth: depth + 1)
    }

    private func point(at distance: CGFloat, samples: [Sample]) -> CGPoint? {
        guard let last = samples.last else { return nil }
        if distance <= 0 { return samples.first?.point }
        if distance >= last.distance { return last.point }
        var low = 0, high = samples.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if samples[mid].distance < distance { low = mid } else { high = mid }
        }
        let a = samples[low], b = samples[high]
        let span = b.distance - a.distance
        guard span > 0 else { return a.point }
        let t = (distance - a.distance) / span
        return CGPoint(x: a.point.x + (b.point.x - a.point.x) * t, y: a.point.y + (b.point.y - a.point.y) * t)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func distanceFromLine(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.0001 else { return hypot(point.x - start.x, point.y - start.y) }
        return abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / length
    }
}
