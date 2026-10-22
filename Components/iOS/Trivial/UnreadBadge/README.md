# UnreadBadge

A SwiftUI unread-count badge inspired by the QQ-style sticky drag-to-dismiss interaction in [KYCuteView](https://github.com/KittenYang/KYCuteView).

```swift
UnreadBadge(count: 8) {
    // Clear the unread count / remove the badge.
}
```

Customize `diameter`, `color`, `textColor`, `font`, `viscosity`, and `breakDistance` as needed. Dragging beyond `breakDistance` breaks the gooey connection, plays a small burst animation, and calls `onDismiss`. Releasing before that distance springs the badge back.

This is a native SwiftUI implementation and does not add an Objective-C or CocoaPods dependency.

The interaction concept is inspired by KYCuteView, Copyright (c) 2015 Qitao Yang, distributed under the MIT License. See the [original repository](https://github.com/KittenYang/KYCuteView) for its license and source.
