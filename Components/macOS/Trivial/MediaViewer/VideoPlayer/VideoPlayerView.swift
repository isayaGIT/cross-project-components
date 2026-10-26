import AVKit
import SwiftUI

/// A lightweight native video player backed entirely by Apple's media frameworks.
///
/// The host supplies a local file URL or a direct HTTP(S) media URL. Playback,
/// decoding, buffering, controls, and full-screen presentation are handled by AVKit.
@MainActor
public struct VideoPlayerView: View {
    private let url: URL
    @State private var player: AVPlayer?

    /// Creates a player for a local media file or a direct media stream.
    ///
    /// Supported codecs and containers depend on the installed macOS version.
    /// HLS playlists are supported when their streams use system-compatible formats.
    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        Group {
            if let player {
                AVKit.VideoPlayer(player: player)
            } else {
                ZStack {
                    Color.black.opacity(0.04)
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(minHeight: 180)
                .accessibilityLabel("Preparing video")
            }
        }
        .task {
            // Defer AVPlayer creation until the view is presented.
            guard player == nil else { return }
            player = AVPlayer(url: url)
        }
        .onChange(of: url) { newURL in
            if let player {
                player.pause()
                player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
            } else {
                player = AVPlayer(url: newURL)
            }
        }
        .onDisappear {
            // Do not keep decoding or playing after its containing view is dismissed.
            player?.pause()
        }
    }
}
