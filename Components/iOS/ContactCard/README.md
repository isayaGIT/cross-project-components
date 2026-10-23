# ContactCard

A polished, native SwiftUI profile card for AI companions / characters. It is designed to be presented as a sheet from an avatar tap, while keeping the two meaningful destinations—chat and the character's Moments feed—explicit and owned by the host app.

## Design decision

Use a **contact-card sheet as the first step**, not an automatic jump to Moments. An avatar tap is an identity/profile affordance; jumping straight into a feed hides the character's identity, relationship context, and the main chat action. The card provides a clear primary **Start Chatting** action and a secondary **View Moments** action. The host decides how those actions navigate, and can omit either callback/button. This also leaves room for relationship state and personality details without turning every avatar tap into a full-screen detour.

The visual direction is closer to an intimate character profile than a literal WeChat business card: editorial portrait, quiet gradient cover, online indicator, relationship chip, compact personality tags, optional stats, and a strong chat CTA. The view does not own routing, image fetching, persistence, or relationship logic.

## Usage

```swift
import ContactCard

let profile = ContactCard.Profile(
    name: "林知夏",
    subtitle: "你的专属 AI 恋人 · 设计师",
    bio: "喜欢在深夜听歌，也喜欢认真听你讲今天发生的小事。",
    avatar: Image("CharacterPortrait"),
    isOnline: true,
    relationshipLabel: "恋爱中 · 相识 28 天",
    tags: ["温柔", "有一点傲娇", "深夜聊天"],
    stats: [
        .init(value: "28 天", label: "相伴"),
        .init(value: "126", label: "条动态")
    ]
)

ContactCard(
    profile: profile,
    onPrimaryAction: { /* dismiss sheet, navigate to chat */ },
    onSecondaryAction: { /* dismiss sheet, navigate to Moments */ },
    onClose: { /* dismiss sheet */ }
)
```

Present it from the avatar interaction using the app's normal `.sheet` / presentation coordinator. Keep the selected character and destination routing in the caller. Supply already-resolved `Image` values; remote image loading belongs to the host app.

## Customization

- `Profile`: name, subtitle, bio, avatar, optional cover, online status, relationship label, personality tags, optional stats.
- `Style`: accent, surface colors, text colors, border, corner radius, horizontal padding.
- Action titles and callbacks are caller-controlled. A button is only shown when both its title and callback are supplied.
- Dynamic Type-friendly text styles, Reduce Motion support, semantic colors, and VoiceOver labels are included.

## Build

```bash
./build.sh
```

Build output and logs remain in this component's local `.build/` directory.
