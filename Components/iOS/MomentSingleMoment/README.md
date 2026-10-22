# MomentSingleMoment

A standalone SwiftUI view for one WeChat-style Moments post. It is intentionally not a feed, composer, or backend client.

## Design

- **Post content:** avatar, author, text, and photos in a WeChat-like 1/2/3-column grid, paged in groups of nine when there are more than nine.
- **Media:** the media grid currently has a temporary NukeUI renderer; replace it with the shared `ImageThumbnail` component once that component API is ready; tapping opens the shared `ImgView` full-screen viewer unless `onMediaTap` is supplied.
- **Metadata:** relative timestamp, optional location and mood.
- **Interactions:** the ellipsis menu sits on the same metadata row as the timestamp and location, and offers Like/Unlike and Comment; likes and comments themselves remain visible below the post. Like state and the displayed people/comments are supplied by the host. This view does not persist data or call a service.

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
- More than 9 photos: retain the complete media collection and paginate in groups of 9. Horizontal swipes switch pages, and page dots at the bottom-right indicate/select the active page.
- The thumbnail rendering is intentionally temporary until the shared `ImageThumbnail` API is available; the grid and pagination container are already separated from that integration point.

## Action icon API

- `Model.isLikedByCurrentUser` drives the outlined/filled Like icon.
- `Model.hasCommentedByCurrentUser` drives the outlined/filled Comment icon. The host should update it when the current user successfully comments.
- `likeIcon`, `likedIcon`, `commentIcon`, and `commentedIcon` optionally accept custom SwiftUI `Image` values. If omitted, SF Symbols are used (`heart`/`heart.fill`, `bubble.right`/`bubble.right.fill`).
- `actionIconTint` optionally overrides the icon tint; by default inactive icons use the palette secondary text color and active icons use the palette accent color.
- The Comment button opens the inline composer directly; there is no secondary action menu.
