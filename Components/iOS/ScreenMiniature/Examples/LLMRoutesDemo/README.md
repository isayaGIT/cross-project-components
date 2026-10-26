# LLM Routes Demo

An isolated, native SwiftUI experiment for the LLM Routes screen. It deliberately leaves the reusable component implementations untouched.

## What it demonstrates

- A horizontal carousel of actual SwiftUI screen hierarchies rendered through the existing `ScreenMiniature` component (chat, research, summary, code, and memory). These are not stock photos or unrelated decorative images.
- A route list showing the task on the left and provider/model on the right.
- Selecting a miniature highlights its matching route; tapping a route opens a compact provider/model picker.
- Spring-based selection, subtle card scaling, and press feedback.

## Run

Open `LLMRoutesDemo.xcodeproj`, choose the `LLMRoutesDemo` scheme, and run on an iPhone simulator. To regenerate the project after editing `project.yml`:

```sh
cd Components/iOS/ScreenMiniature/Examples/LLMRoutesDemo
xcodegen generate
```

This is an experimental visual prototype; its route data is local demo state and is not connected to the app's real LLM configuration.
