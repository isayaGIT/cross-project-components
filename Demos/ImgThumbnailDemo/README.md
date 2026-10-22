# ImgThumbnail Demo

A standalone iOS app for previewing the shared `ImgThumbnail` component's rectangle, smooth rounded rectangle, square crop, and circle crop variants.

## Build and launch

```sh
xcodegen generate --spec project.yml
xcodebuild -project ImgThumbnailDemo.xcodeproj -scheme ImgThumbnailDemo -destination 'platform=iOS Simulator,name=iPhone 15 Plus,OS=18.6' -derivedDataPath /tmp/img-thumbnail-demo-derived CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted /tmp/img-thumbnail-demo-derived/Build/Products/Debug-iphonesimulator/ImgThumbnailDemo.app
xcrun simctl launch booted dev.crossprojectcomponents.imgthumbnaildemo
open -a Simulator
```
