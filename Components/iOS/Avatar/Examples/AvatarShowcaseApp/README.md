# Avatar Showcase App

A small iOS app for running the `AvatarShowcase` examples in the iOS Simulator.

## Run

1. Open `AvatarShowcaseApp.xcodeproj` in Xcode.
2. Select the `AvatarShowcaseApp` scheme and an iOS Simulator.
3. Run the app.

Or build from the repository root:

```sh
cd Components/iOS/Avatar/Examples/AvatarShowcaseApp
xcodegen generate
xcodebuild -project AvatarShowcaseApp.xcodeproj \
  -scheme AvatarShowcaseApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Plus,OS=18.6' build
```

The app uses the local `Avatar` Swift package and the showcase source in the parent `Examples` directory.
