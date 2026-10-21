# VideoPlayerView

A minimal SwiftUI video player for native macOS interfaces. It wraps Apple's AVKit player UI and AVPlayer engine; there are no additional third-party runtime dependencies.

## Usage

    import CrossProjectComponents

    VideoPlayerView(url: videoURL)

The URL may identify a local file, a direct HTTP(S) video URL, or a compatible HLS playlist. A URL pointing to an ordinary webpage is not a media source.

## Scope

- Uses the system playback controls and full-screen experience.
- Defers AVPlayer creation until the view is presented.
- Updates the media item when the supplied URL changes.
- Pauses playback when the containing view disappears.
- Leaves file import, permissions, persistence, playlists, subtitles, and business logic to the host app.
- Does not bundle FFmpeg, VLC, WebView, or other playback engines.

Supported video containers, codecs, audio tracks, and HLS variants depend on the current macOS version and source encoding; this component does not transcode unsupported media.

## Open-source reference

The API choice and lightweight scope were cross-checked against [SwiftPlayer](https://github.com/scadavide55/SwiftPlayer), an MIT-licensed native macOS player. No SwiftPlayer source files are copied into this component; playback and controls use Apple's AVKit and AVFoundation frameworks.
