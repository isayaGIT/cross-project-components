# LLM Routes Demo

An isolated, native SwiftUI recreation of the LLM Routes reference screen. It keeps the reference's compact serif heading, horizontal scenic task carousel, pastel canvas, and eight-row task-routing panel. Scenic artwork is bundled as individual image assets; the surrounding interface is real SwiftUI, not a flattened screenshot.

## Interactions

- Swipe the horizontal carousel or use its arrows to move between task previews. The selected carousel position and pagination dots stay synchronized.
- Tap any route row to open the provider/model picker. Choosing a provider updates that row's provider and model.
- The settings control can reset provider assignments; the Add Route control explains that all eight reference routes are already configured in this fixed demo.

Route assignments are local demo state and are not connected to the app's real LLM configuration.

## Run

Open `LLMRoutesDemo.xcodeproj`, choose the `LLMRoutesDemo` scheme, and run on an iPhone simulator. To regenerate the project after editing `project.yml`:

```sh
cd Components/iOS/ScreenMiniature/Examples/LLMRoutesDemo
xcodegen generate
```
