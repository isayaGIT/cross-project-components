# InputContainer

`InputContainer` owns the complete input region and coordinates its controls and auxiliary panels.

- `InputBar` is only the capsule visual surface.
- The Add button, text field, sticker button, and send/stop controls are composed by `InputContainer`.
- `toolsPanel` is optional content revealed by the Add button.
- `accessoryPanel` is optional sticker/emoji content revealed by the sticker button.
- The container ensures the tools panel and sticker panel do not show simultaneously.
- When embedded in `ScreenChatContainer`, focus and sticker-panel state can be shared through `ScreenChatContainerInputContext`.

The host supplies the actual actions and panel content. The input components do not assume how a camera, photo picker, file picker, or sticker selection should be handled by an app.
