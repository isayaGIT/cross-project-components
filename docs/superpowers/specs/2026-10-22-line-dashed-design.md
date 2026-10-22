# LineDashed Component Design

Date: 2026-10-22
Status: Draft for user review
Repository: `cross-project-components`

## 1. Summary

Build `LineDashed` as a reusable SwiftUI component distributed as an independent local Swift Package under `Shapes/LineDashed`, and integrate that package into the main repository by referencing the same source package. The component renders each dash as an independent rounded-rectangle segment positioned along a path. It supports arbitrary paths and convenience APIs for rectangles and rounded rectangles.

The architecture separates path geometry, dash layout, fill/pattern rendering, and platform-specific material effects. Static rendering is the default; optional marching-dash animation changes only the dash phase/offset and should reuse cached geometry where possible.

## 2. Goals

- Provide a reusable dashed-path component for iOS, iPadOS, and macOS.
- Support straight lines, arcs, curves, custom paths, and rectangle/rounded-rectangle convenience initializers.
- Represent every dash as an independent rounded-rectangle segment, with configurable width, length, spacing, and corner radius.
- Support solid colors, linear/radial/angular gradients, repeating patterns (initially checkerboard and grid), and platform-adapted system materials.
- Make path geometry independent of the fill renderer so new fill types do not require changes to path sampling or dash placement.
- Support closed-path layout modes: automatic even distribution by default, plus fixed dash length/spacing as an explicit option.
- Keep static mode free of automatic animation work and provide optional dash-flow animation.
- Recover safely from invalid configuration and invalid geometry.
- Include a standalone interactive Showcase App, package tests, and documentation.

## 3. Non-goals for the first version

- A general shader-authoring framework.
- A general animation orchestration/state-management framework.
- A third-party graphics engine or mandatory external runtime dependency.
- Unrelated border, shadow, layout, or interaction frameworks.
- A second copy of the component source inside the root package.

## 4. Architecture

### 4.1 Layers

1. **Public SwiftUI API** — `LineDashed`, configuration types, path conveniences, fill and animation options.
2. **Path engine** — samples the input path by arc length and derives segment positions and tangent orientations.
3. **Dash layout** — determines segment start/end positions, gaps, closed-path distribution, corner radius, and animation phase.
4. **Rendering** — draws normal fills and patterns efficiently; uses a separate SwiftUI view/effect layer only for material effects that cannot be represented as ordinary drawing styles.
5. **Platform adapters** — gates system-material and Liquid Glass effects by platform and OS availability, with a safe fallback when unavailable.

### 4.2 Geometry contract

Each dash is an independent rounded-rectangle segment oriented along the path tangent at its placement. `lineWidth` controls segment thickness; `dashLength` controls segment length; `dashSpacing` controls the gap. `cornerRadius` is clamped to the segment's actual half-short-side limit. A radius of zero produces square corners.

For arbitrary curves, the path engine must place dashes according to path distance rather than naïve uniform parameter values, so visual spacing does not vary with curve parameterization. Geometry must avoid negative dimensions, non-finite coordinates, and invalid transforms.

### 4.3 Closed and open paths

- Closed paths default to **automatic even distribution**, balancing the dash/gap pattern around the loop to avoid an anomalously short remainder at the seam.
- Closed paths also expose **fixed length/spacing** mode, which preserves requested dash length and gap and accepts that the seam may have a different remainder.
- Open paths default to fixed dash length and spacing. A trailing remainder shorter than one full dash is not forcibly stretched into a full segment.
- Zero spacing is valid and allows segments to touch; segments remain logically separate.
- Empty or unusable paths render nothing.

The exact mathematical distribution algorithm and tolerance policy will be specified in the implementation plan and covered by tests.

## 5. Fill, pattern, and material model

### 5.1 Fill coordinates

The fill model supports both:
- **Path-continuous fill** — the default; a gradient or pattern uses a stable coordinate space across the entire path/shape.
- **Per-segment fill** — each dash gets its own fill coordinate space, allowing the gradient or pattern to restart on every segment.

The fill coordinate mode is independent from the path engine.

### 5.2 First-version fill types

- Solid color.
- Linear, radial, and angular gradients.
- Checkerboard and grid patterns.
- Extensible custom pattern rendering interface.

Pattern geometry and its coordinate space must be deterministic. Adding a new fill or pattern must not require modifying path sampling or dash layout.

### 5.3 Materials and Liquid Glass

System materials and Liquid Glass are treated as visual-effect rendering options, not assumed to be interchangeable with ordinary `ShapeStyle` values. Material rendering is platform/OS gated. Where a requested effect is unavailable, use a documented safe fallback without disabling ordinary fill rendering. Avoid raising the minimum deployment target for the whole package solely to enable a special effect.

## 6. Rendering strategy

Use a **hybrid rendering architecture**:
- Shared geometry results are produced independently of the renderer.
- Ordinary solid, gradient, and pattern segments use centralized drawing where practical, avoiding a full independent SwiftUI view for every dash.
- Effects that require SwiftUI view-level composition (for example, some material/glass treatments) may use a dedicated view layer, aligned to the same computed segment geometry.
- Rendering changes must not change the path/dash geometry contract.

## 7. Public API direction

The exact type names can be refined during implementation, but the public concepts should remain stable:

- `LineDashed`: main SwiftUI view with generic path input and rectangle/rounded-rectangle conveniences.
- `DashedLineConfiguration`: line width, dash length, spacing, corner radius, and closed-path layout mode.
- `DashedLineFill`: solid color, gradients, and continuous/per-segment fill mode.
- `DashedLinePattern`: checkerboard, grid, and an extensible custom-pattern path.
- `DashedLineMaterial`: system-material and Liquid Glass effect choices with platform availability handling.
- `DashedLineAnimation`: opt-in dash-flow offset/phase; static by default.

These are conceptual names, not a promise to introduce a separate public type where a simpler API proves more maintainable. Public APIs should favor explicit, type-safe configuration and should avoid forcing consumers to manage internal renderers.

Illustrative usage:

```swift
LineDashed(
    path: path,
    configuration: .init(
        lineWidth: 3,
        dashLength: 10,
        dashSpacing: 5,
        cornerRadius: 2
    ),
    fill: .color(.blue)
)
```

The exact syntax for type-erased styles, custom patterns, and view-level materials must be chosen to compile cleanly across supported Apple platforms.

## 8. Parameter validation and failure behavior

Configuration is normalized centrally and invalid geometry safely degrades:
- Non-finite numeric values are rejected from geometry calculations and lead to safe defaults or no drawing as appropriate.
- Negative line width and dash length are normalized to a safe non-drawing/default behavior; they must never create negative geometry.
- Negative spacing is clamped to zero.
- Corner radius is clamped to the actual segment bounds.
- Empty paths and paths that cannot fit a valid segment render nothing.
- Renderer failures or unavailable platform effects must not crash the host view.
- The README documents each normalization rule so callers can predict behavior.

Prefer deterministic normalization over scattered ad hoc checks. No invalid value should propagate into drawing transforms.

## 9. Package and repository integration

Target structure:

```text
Shapes/LineDashed/
  Package.swift
  Sources/LineDashed/
    LineDashed.swift
    DashedLineConfiguration.swift
    DashedLinePathEngine.swift
    DashedLineLayout.swift
    DashedLineFill.swift
    DashedLinePattern.swift
    DashedLineMaterial.swift
    DashedLineRenderer.swift
    DashedLineAnimation.swift
  Tests/LineDashedTests/
  Examples/
    LineDashedShowcaseApp/
  README.md
```

This is a logical organization proposal; files may be combined where separation would add needless complexity.

- The package is independently consumable.
- The root package references the local package/product rather than copying the implementation.
- Reuse the existing `RoundedRectSmoothed` implementation where feasible through a stable shared package/module boundary; do not maintain a divergent duplicate.
- Prefer Apple system frameworks. No third-party dependency is planned unless implementation demonstrates a concrete need.
- The Showcase App is a standalone interactive app and must not interfere with existing demos or tests.

## 10. Platform support

- Primary platforms: iOS, iPadOS, and macOS.
- Core path geometry, dash layout, solid fills, gradients, and patterns should be shared.
- Platform-specific effects are guarded by availability and have a safe fallback.
- Platform deployment targets must be consistent with the repository's supported targets and must not be raised only for Liquid Glass.

## 11. Animation and update behavior

- Static mode is the default and starts no timer or continuous update loop.
- Optional dash-flow animation updates the dash phase/offset and reuses precomputed geometry where possible.
- Changes to path, dimensions, width, dash length, spacing, radius, or closed-path layout invalidate relevant geometry.
- Changes to color/gradient stops should not trigger path resampling unless their coordinate definitions depend on changed geometry.
- Animation should not require creating a complete independent SwiftUI view per segment.
- The initial version does not include a general-purpose animation framework or promise animated interpolation for every configuration field.

## 12. Testing and acceptance criteria

### Geometry
- Straight, arc, curved, custom, rectangular, and rounded-rect paths produce segments at correct arc-length intervals.
- Segment orientation follows the local path tangent.
- Corner radius zero yields square-corner segments; excessive radius is clamped.
- Closed-path even-distribution mode balances the seam; fixed mode preserves dash length and spacing.
- Open paths preserve requested spacing and do not force-fill a short remainder.
- Empty, very short, degenerate, and non-finite paths fail safely.

### Fill and rendering
- Continuous gradients do not restart per dash.
- Per-segment gradients do restart per dash.
- Checkerboard and grid patterns use the selected coordinate mode consistently.
- Adding a fill/pattern implementation does not require editing the geometry engine.
- Unavailable material/glass effects fall back safely.

### Package and platforms
- The standalone package builds and tests.
- Root package resolves the local package without a duplicate source target.
- iOS, iPadOS, and macOS compile checks pass for supported deployment targets.
- The Showcase App exposes live controls for path type, width, dash length, spacing, radius, fill mode, fill type, closed-path mode, and optional animation.
- Static mode does not perform continuous updates.
- README includes installation/use examples, supported platforms, behavior rules, and limitations.

Performance validation should include a representative path with many dashes and repeated phase updates; exact numeric performance budgets should be selected after establishing a baseline on the target environment.

## 13. Risks and decisions to validate during implementation

- Accurate arc-length sampling for arbitrary SwiftUI paths is the most algorithmically sensitive part; tests must cover curves and degenerate segments.
- A continuous fill on rotated individual dash shapes needs a stable global coordinate strategy to avoid gradients restarting or seams appearing.
- SwiftUI materials and Liquid Glass do not share identical availability or rendering semantics across platforms.
- Reusing `RoundedRectSmoothed` must not create a circular package dependency; select a dependency direction that leaves a single source of truth.
- SwiftUI `ShapeStyle` type erasure and pattern APIs differ in ergonomics; choose compile-tested public signatures rather than locking to illustrative syntax prematurely.

## 14. Delivery sequence

1. User reviews and approves this written design spec; revise it if requested.
2. Write a detailed implementation plan with file-level steps and validation commands.
3. Implement the path engine and configuration with geometry tests first.
4. Implement fill coordinate modes and initial pattern renderers.
5. Add platform-specific material adapter and opt-in animation.
6. Add standalone Showcase App and documentation.
7. Integrate the local package into the root package without disturbing unrelated changes.
8. Run targeted package tests and supported-platform build checks; report any platform/runtime limitations explicitly.

