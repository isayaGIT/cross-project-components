# ProfileCard

A reusable, presentation-only profile card for either the current user or a character. The host supplies resolved images, the latest image/video moments, and action callbacks; this component owns no networking, persistence, or navigation.

```swift
ProfileCard(
    profile: .init(
        name: "林知夏",
        signature: "把日常过成喜欢的样子",
        status: .online,
        profileImage: Image("profile-avatar"),
        profileBackgroundImage: Image("profile-cover"),
        cardBackgroundImage: Image("profile-card-background"),
        recentMoments: [
            .init(thumbnail: Image("moment-1")),
            .init(thumbnail: Image("moment-2"), isVideo: true)
        ]
    ),
    style: .init(nameFontSize: 24, group1: .pink, group2: .purple),
    onVoiceCall: { /* host starts voice call */ },
    onListenTogether: { /* host starts a shared listening session */ },
    onMessage: { /* host opens or focuses this conversation */ }
)
```

`Profile` is shared by users and characters. Its status supports `online`, `offline`, `replying`, and `error`. Pass only moments with image/video media; the card displays the first four as square thumbnails and overlays a play icon for videos. `profileBackgroundImage` is the horizontal cover, while `cardBackgroundImage` paints the whole card.

`Style` configures name/signature/status typography, the five accent groups, card geometry, recent-moment thumbnail size, and action button fonts/colors. Voice call and listen-together actions use compact widths; the message action fills the remaining row. The card uses its own elevation shadow rather than dimming the entire screen. The host owns the actual action implementations.
