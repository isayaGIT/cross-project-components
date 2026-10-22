import SwiftUI

/// The mirrored, gradient-and-glow waveform used by ZPing's voice input bar.
/// On iOS the display-link conveyor preserves a constant leftward flow even
/// during silence; the non-UIKit fallback keeps the target buildable on macOS.
struct ComposerWaveformBar: View {
    let amplitudes: [Float]
    let style: MessageComposer.Style

    private let barCount = 31
    private let minScale: CGFloat = 0.05

#if canImport(UIKit)
    @State private var conveyor = WaveformConveyor()
#else
    @State private var displayAmplitudes = Array(repeating: Float(0.05), count: 31)
#endif
    @State private var lastAmplitudeCount = 0

    var body: some View {
        Canvas { context, size in
            drawBars(context: &context, size: size, amplitudes: renderedAmplitudes)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Capsule().fill(style.fieldBackground))
        .onAppear {
#if canImport(UIKit)
            conveyor.start()
            if !amplitudes.isEmpty { conveyor.enqueue(amplitudes) }
#else
            displayAmplitudes = Array(amplitudes.suffix(barCount))
#endif
            lastAmplitudeCount = amplitudes.count
        }
        .onDisappear {
#if canImport(UIKit)
            conveyor.stop()
#endif
        }
        .onChangeCompat(of: amplitudes) { newValues in
#if canImport(UIKit)
            if newValues.count < lastAmplitudeCount {
                conveyor.reset()
                lastAmplitudeCount = newValues.count
            } else if newValues.count > lastAmplitudeCount {
                let delta = newValues.count - lastAmplitudeCount
                conveyor.enqueue(Array(newValues.suffix(delta)))
                lastAmplitudeCount = newValues.count
            }
#else
            displayAmplitudes = Array(newValues.suffix(barCount))
            lastAmplitudeCount = newValues.count
#endif
        }
        .accessibilityLabel("录音音量波形")
    }

    private var renderedAmplitudes: [Float] {
#if canImport(UIKit)
        conveyor.displayAmplitudes
#else
        displayAmplitudes
#endif
    }

    private func drawBars(context: inout GraphicsContext, size: CGSize, amplitudes: [Float]) {
        let barWidth: CGFloat = 2
        let barSpacing: CGFloat = 2.5
        let cornerRadius: CGFloat = 1
        let step = barWidth + barSpacing
        let totalWidth = CGFloat(barCount) * step - barSpacing
        let startX = (size.width - totalWidth) / 2
        let midY = size.height / 2
        let maxHalfHeight = (size.height / 2) - 2
        let glowColor = style.waveformGlowColor

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            for index in 0..<barCount {
                let sample = index < amplitudes.count ? CGFloat(amplitudes[index]) : 0
                let halfHeight = max(minScale * maxHalfHeight, sample * maxHalfHeight)
                guard halfHeight > 0 else { continue }
                let x = startX + CGFloat(index) * step
                let glowRect = CGRect(
                    x: x - 1,
                    y: midY - halfHeight - 1,
                    width: barWidth + 2,
                    height: halfHeight * 2 + 2
                )
                layer.fill(Path(roundedRect: glowRect, cornerRadius: cornerRadius + 1), with: .color(glowColor))
            }
        }

        let gradient = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [style.accent, style.waveformBaseColor, style.accent]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: midY * 2)
        )

        for index in 0..<barCount {
            let sample = index < amplitudes.count ? CGFloat(amplitudes[index]) : 0
            let halfHeight = max(minScale * maxHalfHeight, sample * maxHalfHeight)
            let x = startX + CGFloat(index) * step
            let upper = CGRect(x: x, y: midY - halfHeight, width: barWidth, height: halfHeight)
            let lower = CGRect(x: x, y: midY, width: barWidth, height: halfHeight)
            context.fill(Path(roundedRect: upper, cornerRadius: cornerRadius), with: gradient)
            context.fill(Path(roundedRect: lower, cornerRadius: cornerRadius), with: gradient)
        }
    }
}
