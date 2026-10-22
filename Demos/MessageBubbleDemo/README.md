# MessageBubble Demo

A standalone iOS app for visually inspecting the `MessageBubble` component. It previews incoming and outgoing bubbles, supports live left/right sharp-corner selection, adjusts the radius, and toggles a gradient fill. The gallery shows all four supported square-corner positions.

## Build and launch

From this directory:

```sh
USER="$(id -un)" LOGNAME="$(id -un)" xcodegen generate --spec project.yml
xcodebuild -project MessageBubbleDemo.xcodeproj \
  -scheme MessageBubbleDemo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Plus,OS=18.6' \
  -derivedDataPath /tmp/message-bubble-demo-derived \
  CODE_SIGNING_ALLOWED=NO build
```

To install and launch on a booted simulator:

```sh
xcrun simctl install booted /tmp/message-bubble-demo-derived/Build/Products/Debug-iphonesimulator/MessageBubbleDemo.app
xcrun simctl launch booted dev.crossprojectcomponents.messagebubbledemo
open -a Simulator
```
