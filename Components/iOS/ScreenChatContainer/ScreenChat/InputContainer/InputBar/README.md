# InputBar

`InputBar` is the visual capsule surface behind the chat composer. It does not own the Add button, text field, sticker button, send/stop controls, or any panel state. Those controls and their cross-component layout are composed by `InputContainer`.

```swift
ZStack {
    InputBar()
    // InputContainer owns and lays out the composer controls above this surface.
}
```

The capsule uses the regular material on earlier OS versions and the native glass effect where available. Keep interaction state and panel transitions in `InputContainer`.
