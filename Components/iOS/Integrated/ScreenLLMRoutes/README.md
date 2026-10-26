# Screen LLM Routes

A self-contained, native SwiftUI recreation of the LLM Routes reference screen. The screen, its supporting view logic, launch storyboard, asset catalog, scenic source artwork, and standalone Xcode project live together in this folder.

The interface uses real SwiftUI controls and layout; it does not render a flattened screenshot as the app screen.

## Interactions

- Swipe the scenic carousel or use its arrows to move between task previews.
- Tap any route row to open the provider/model picker. Choosing a provider updates that row's provider and model.
- The settings control resets provider assignments; Add Route explains that all eight routes from the reference are already present in this fixed demo.

Route assignments are local demo state and are not connected to the host app's real LLM configuration.

## Build and run

Open `LLMRoutesDemo.xcodeproj`, select the `LLMRoutesDemo` scheme, and run on an iPhone simulator. To regenerate the Xcode project after editing `project.yml`:

```sh
cd Components/iOS/Integrated/ScreenLLMRoutes
xcodegen generate
```

The project references the shared `ScreenMiniature` package at `Components/iOS/ScreenMiniature`.
