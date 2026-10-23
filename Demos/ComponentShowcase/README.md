# Component Showcase

A small iOS app for trying the reusable motion and interaction components in this repository.

- **Gestures:** swipe actions and elastic button feedback
- **Chat:** waveform scrubbing and follow-scroll behavior
- **Notices:** stacked notices, swipe-to-dismiss, expansion, and clear-all

## Build and run

```sh
xcodegen --spec Demos/ComponentShowcase/project.yml --project Demos/ComponentShowcase
xcodebuild -project Demos/ComponentShowcase/ComponentShowcase.xcodeproj \
  -scheme ComponentShowcase \
  -destination 'platform=iOS Simulator,name=iPhone 15 Plus' \
  -derivedDataPath /tmp/ComponentShowcaseDerived \
  CODE_SIGNING_ALLOWED=NO build
```

The app bundles a short synthesized voice sample so waveform scrubbing can be tried without a network connection.
