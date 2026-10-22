# MomentSingleMoment

A standalone SwiftUI view for one WeChat-style Moments post. It is intentionally not a feed, composer, or backend client.

## Design

- **Post content:** avatar, author, text, and photos in a WeChat-like 1/2/3-column grid, paged in groups of nine when there are more than nine.
- **Media:** thumbnails use the shared `ImgThumbnail` component; tapping opens the shared `ImgView` full-screen viewer unless `onMediaTap` is supplied.
- **Metadata:** relative timestamp, optional location and mood.
- **Interactions:** a single ellipsis menu offers Like/Unlike and Comment, matching WeChat Moments. The likes and comments panel remains visible below the post. The host supplies authoritative state through `Model` and handles changes through callbacks; this view does not persist data or call a service.

## Example

```swift
import SwiftUI
import CrossProjectComponentsIOS

struct MomentExample: View {
    private let author = MomentSingleMoment.Person(id: "author-1", name: "莓莓")
    @State private var liked = false
    @State private var likes: [MomentSingleMoment.Person] = []
    @State private var comments: [MomentSingleMoment.Comment] = []

    var body: some View {
        MomentSingleMoment(
            model: .init(
                author: author,
                text: "今天的光线刚刚好。",
                location: "公园",
                isLikedByCurrentUser: liked,
                likes: likes,
                comments: comments
            ),
            onToggleLike: { isLiked in
                liked = isLiked
                if isLiked {
                    likes = [MomentSingleMoment.Person(id: "me", name: "我")]
                } else {
                    likes.removeAll { $0.id == "me" }
                }
            },
            onComment: { text in
                comments.append(.init(author: .init(id: "me", name: "我"), text: text))
            }
        )
    }
}
```

## Integration

The component lives in the root `CrossProjectComponentsIOS` target and uses the existing Nuke/NukeUI dependency, `ImgData` image metadata module, shared design palette, and `ImgView` viewer. Callbacks are the integration boundary: the parent owns network requests, persistence, current-user identity, and authoritative interaction state.

## Media layout contract

- 1 photo: one larger tile; 2 photos: 2 columns; 3 photos: 3 columns.
- 4 photos: 2×2; 5 photos: 3+2; 6 photos: 3+3; 7 photos: 3+3+1; 8 photos: 3+3+2; 9 photos: 3×3.
- More than 9 photos: retain the complete media collection and paginate in groups of 9. Horizontal swipes switch pages, and page dots in the metadata row indicate/select the active page.
- The thumbnail rendering is intentionally temporary until the shared `ImageThumbnail` API is available; the grid and pagination container are already separated from that integration point.

## Public API

The public surface is intentionally small: `Model`, `Person`, `Media`, and `Comment` describe display data; `onToggleLike` and `onComment` report user intent; `onAuthorTap` and `onMediaTap` are optional navigation overrides. No backend, persistence, icon customization layer, or feed state is included. Styling uses the shared `ComponentDesignPalette.warmEmber` token set internally, so the initializer stays focused on content and behavior.
