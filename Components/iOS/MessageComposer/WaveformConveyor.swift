#if canImport(UIKit)
import Observation
import UIKit

/// Constant-speed waveform conveyor extracted from ZPing. Incoming audio
/// samples enter from the right while old samples move left. During silence,
/// a subtle idle pattern keeps the waveform visually alive.
@Observable
final class WaveformConveyor {
    var displayAmplitudes: [Float] = []

    private var targetAmplitudes: [Float] = []
    private var pendingSamples: [Float] = []
    private var displayLink: CADisplayLink?
    private var tickCount = 0
    private let barCount = 31
    private let minScale: Float = 0.05
    private let lerpSpeed: Float = 0.35
    private let shiftInterval = 4
    private let idlePattern: [Float]
    private var idleIndex = 0

    init() {
        let minimumScale: Float = 0.05
        let idlePeak = minimumScale * 2.5
        let patternLength = barCount * 2
        self.idlePattern = (0..<patternLength).map { index in
            let phase = Float(index) / Float(patternLength) * 2 * .pi
            let sine = (sinf(phase) + 1) / 2
            return minimumScale + sine * (idlePeak - minimumScale)
        }
    }

    func start() {
        displayAmplitudes = Array(repeating: minScale, count: barCount)
        targetAmplitudes = Array(repeating: minScale, count: barCount)
        pendingSamples.removeAll()
        tickCount = 0
        idleIndex = 0
        let proxy = DisplayLinkProxy(owner: self)
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func enqueue(_ samples: [Float]) {
        pendingSamples.append(contentsOf: samples)
    }

    func reset() {
        targetAmplitudes = Array(repeating: minScale, count: barCount)
        pendingSamples.removeAll()
        tickCount = 0
    }

    fileprivate func tick(_ link: CADisplayLink) {
        guard displayAmplitudes.count == barCount else {
            displayAmplitudes = Array(repeating: minScale, count: barCount)
            targetAmplitudes = Array(repeating: minScale, count: barCount)
            return
        }

        tickCount += 1
        if tickCount >= shiftInterval {
            tickCount = 0
            for index in 0..<(barCount - 1) {
                targetAmplitudes[index] = targetAmplitudes[index + 1]
            }
            if let sample = pendingSamples.first {
                pendingSamples.removeFirst()
                targetAmplitudes[barCount - 1] = max(minScale, sample)
            } else {
                targetAmplitudes[barCount - 1] = idlePattern[idleIndex]
                idleIndex = (idleIndex + 1) % idlePattern.count
            }
        }

        for index in 0..<barCount {
            displayAmplitudes[index] += (targetAmplitudes[index] - displayAmplitudes[index]) * lerpSpeed
        }
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var owner: WaveformConveyor?

    init(owner: WaveformConveyor) {
        self.owner = owner
    }

    @objc func tick(_ link: CADisplayLink) {
        owner?.tick(link)
    }
}
#endif
