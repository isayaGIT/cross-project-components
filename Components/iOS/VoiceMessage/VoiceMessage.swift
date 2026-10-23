import AVFoundation
import SwiftUI

/// Selects the visual and interaction density of a voice message.
public enum VoiceMessageDisplayMode: String, CaseIterable, Sendable {
    /// A compact, WeChat-style row. Playback is supported, but seeking is intentionally hidden.
    case compact
    /// A waveform player with a seekable timeline.
    case waveform
}

/// A reusable voice-message player for chat, comments, and feed content.
///
/// The host owns the audio URL and chooses the presentation mode. Playback, timing, and player
/// lifecycle are shared by both modes. The compact mode deliberately does not expose seeking.
public struct VoiceMessageView: View {
    private let audioURL: URL
    private let displayMode: VoiceMessageDisplayMode
    private let durationOverride: TimeInterval?
    private let waveform: [CGFloat]?
    private let tint: Color
    private let foreground: Color
    private let background: Color
    private let width: CGFloat?

    @StateObject private var playback: VoiceMessagePlaybackController
    @State private var samples: [Float] = []
    @State private var playbackRate: Double = 1

    /// Creates a voice message player.
    /// - Parameters:
    ///   - audioURL: A local file URL or a URL supported by `AVPlayer`.
    ///   - displayMode: `.compact` for a simple play/duration row, or `.waveform` for a seekable waveform.
    ///   - duration: Optional known duration. When omitted, duration is read from the media item.
    ///   - waveform: Optional normalized bar heights. Values are clamped to `0...1`; a stable placeholder waveform is used when omitted in waveform mode.
    ///   - tint: Play control and played waveform color.
    ///   - foreground: Text and unplayed waveform color.
    ///   - background: Optional control background; defaults to a subtle system background.
    ///   - width: Optional preferred width. Leave `nil` to size naturally within the parent.
    public init(
        audioURL: URL,
        displayMode: VoiceMessageDisplayMode = .compact,
        duration: TimeInterval? = nil,
        waveform: [CGFloat]? = nil,
        tint: Color = .accentColor,
        foreground: Color = .primary,
        background: Color = Color.secondary.opacity(0.08),
        width: CGFloat? = nil
    ) {
        self.audioURL = audioURL
        self.displayMode = displayMode
        self.durationOverride = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.waveform = waveform
        self.tint = tint
        self.foreground = foreground
        self.background = background
        self.width = width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        _playback = StateObject(wrappedValue: VoiceMessagePlaybackController(url: audioURL))
    }

    private var totalDuration: TimeInterval {
        durationOverride ?? playback.duration
    }

    public var body: some View {
        Group {
            switch displayMode {
            case .compact:
                compactPlayer
            case .waveform:
                waveformPlayer
            }
        }
        .frame(width: width, alignment: .leading)
        .onChange(of: audioURL) { _, newURL in playback.load(url: newURL) }
        .onChange(of: playbackRate) { _, newRate in playback.setPlaybackRate(newRate) }
        .onDisappear { playback.pause() }
    }

    private var compactPlayer: some View {
        HStack(spacing: 10) {
            playButton(size: 30)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(foreground.opacity(0.85))
                .accessibilityHidden(true)
            Text(formattedTime(totalDuration))
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice message, \(formattedTime(totalDuration))")
    }

    private var waveformPlayer: some View {
        WaveformScrub(
            samples: waveform.map { $0.map { Float($0) } } ?? samples,
            duration: totalDuration,
            time: playback.currentTime,
            isPlaying: playback.isPlaying,
            rate: $playbackRate,
            onPlayPause: { playback.togglePlayback() },
            onSeek: { playback.seek(to: $0, durationLimit: totalDuration) }
        )
        .frame(maxWidth: width ?? .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: audioURL) {
            guard waveform == nil else { return }
            samples = (try? await WaveformScrub.samples(from: audioURL)) ?? []
        }
        .accessibilityLabel("Voice message waveform")
    }

    private func playButton(size: CGFloat) -> some View {
        Button {
            playback.togglePlayback()
        } label: {
            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playback.isPlaying ? "Pause voice message" : "Play voice message")
        .accessibilityHint("Plays the voice message")
    }

    private var normalizedWaveform: [CGFloat] {
        if let waveform, !waveform.isEmpty {
            return waveform.map { $0.isFinite ? min(1, max(0, $0)) : 0.25 }
        }
        // Stable visual fallback: no random heights between renders.
        return (0..<fortyWaveformBars).map { index in
            let sine = sin(Double(index) * 1.71)
            let cosine = cos(Double(index) * 0.37)
            let wave = abs(sine * cosine)
            return CGFloat(0.18 + wave * 0.82)
        }
    }

    private var fortyWaveformBars: Int { 40 }

    private func barWidth(for width: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 2 }
        return max(1.5, min(3, (width - CGFloat(count - 1) * 2) / CGFloat(count)))
    }

    private func barSpacing(for width: CGFloat, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        let barWidth = barWidth(for: width, count: count)
        return max(0.5, min(2, (width - CGFloat(count) * barWidth) / CGFloat(count - 1)))
    }

    private func barHeight(_ value: CGFloat) -> CGFloat {
        5 + min(1, max(0, value)) * 29
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let wholeSeconds = Int(min(seconds, TimeInterval(Int.max)))
        return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}

@MainActor
private final class VoiceMessagePlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVPlayer
    private var playbackRate: Double = 1
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var url: URL

    init(url: URL) {
        self.url = url
        self.player = AVPlayer(url: url)
        installObservers()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func load(url newURL: URL) {
        guard url != newURL else { return }
        url = newURL
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            if duration > 0, currentTime >= duration {
                seek(to: 0)
            }
            player.playImmediately(atRate: Float(playbackRate))
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func setPlaybackRate(_ rate: Double) {
        guard rate.isFinite, rate > 0 else { return }
        playbackRate = rate
        if isPlaying { player.rate = Float(rate) }
    }

    func seek(to seconds: TimeInterval, durationLimit: TimeInterval? = nil) {
        let seekDuration = duration > 0 ? duration : (durationLimit ?? 0)
        guard seconds.isFinite, seekDuration.isFinite, seekDuration > 0 else { return }
        let target = min(seekDuration, max(0, seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
    }

    private func installObservers() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                let seconds = time.seconds
                if seconds.isFinite, seconds >= 0 { self.currentTime = seconds }
                let itemDuration = self.player.currentItem?.duration.seconds ?? 0
                if itemDuration.isFinite, itemDuration > 0 { self.duration = itemDuration }
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, notification.object as? AVPlayerItem === self.player.currentItem else { return }
                self.player.pause()
                self.player.seek(to: .zero)
                self.currentTime = 0
                self.isPlaying = false
            }
        }
    }
}
