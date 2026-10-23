# ProfileCard

A static SwiftUI profile card for both the current user and fictional characters. This package is frontend-only: the caller supplies already-resolved `Image` values and owns image loading, persistence, navigation, and actions.

## Usage

```swift
import SwiftUI
import ProfileCard

ProfileCard(
    profile: .init(
        name: "林知夏",
        signature: "把日常过成喜欢的样子",
        profileImage: Image("profile-avatar"),
        profileBackgroundImage: Image("profile-cover"),
        cardBackgroundImage: Image("profile-card-background")
    ),
    style: .init(
        nameFontSize: 24,
        nameColor: .primary,
        signatureFontSize: 13,
        signatureColor: .secondary,
        group1: .pink,
        group2: .purple
    )
)
```

## API boundary

- `profileImage`: portrait/avatar.
- `profileBackgroundImage`: the top cover behind the portrait.
- `cardBackgroundImage`: static image behind the entire card; when omitted, `style.cardColor` is used.
- `nameFontName` / `signatureFontName`: optional installed/custom font names. Empty or `nil` uses the built-in system font.
- `group1` / `group2`: primary and secondary theme colors, available for the current presentation and future controls.
- No networking, image loading, persistence, routing, or business actions are included.
