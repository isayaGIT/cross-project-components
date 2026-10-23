# NoticeStack

A reusable stack of in-app notices with expand/collapse, swipe-to-dismiss, individual close buttons, optional actions, and clear-all behavior. The host owns the `NoticeStackItem` array and all business logic.

```swift
@State private var notices: [NoticeStackItem] = [
    NoticeStackItem(
        title: "Upload complete",
        message: "Your photos are ready.",
        systemImage: "checkmark.circle.fill",
        tint: .green,
        actionTitle: "View photos",
        action: { openPhotos() }
    )
]

NoticeStack(notices: $notices)
```

The stack uses system materials and semantic colors by default. Set `maximumVisibleCards` to control the number of cards shown before expansion (1–5). It does not schedule expiration timers or persist notices.
