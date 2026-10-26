# PVC Card Holder — Embedded Button / Deforming Center Highlight Task

## Goal

Implement and validate a button embedded **inside the existing card's central content area**. This is not a standalone button-material demo. The reference is the current `CardGeneral` PVC/card shader and, specifically, its broad, relatively flat white center highlight.

## Required visual/technical behavior

- Keep the existing card and its material rendering as the scene being tested.
- Add a switch to show/hide a button placed within the card's content region (not on the rim and not outside the card).
- The button must have a controllable raised/pressed state.
- The existing broad white center highlight must pass over the button and deform continuously according to the button's height profile. The highlight/reflection should bend, shift, compress, or otherwise respond to the raised/pressed surface normals and reflection direction.
- The highlight must not look like a static white overlay pasted over a button. It should read as the same card/environment reflection interacting with a local 3D protrusion.
- Preserve the original card appearance when the button is disabled. Keep an on/off control for the embedded button.
- Keep the experiment isolated to `Our Own Version`; do not modify the archived read-only reference under `cross-project-textures/PVC-Card-Holder`.

## Implementation direction

- First understand the existing `CardGeneralMetalRenderer` and its center-highlight pass. Reuse and extend that rendering path instead of creating a separate standalone Metal button renderer.
- Introduce a local button height field/SDF into the card's surface-normal/reflection calculation. The button's state should alter the height profile and therefore the normal/reflection field used to produce the existing center highlight.
- Keep content artwork and button graphics separate from the card's specular pass; do not mistake a generic button edge bevel/highlight for the requested center reflection deformation.
- Prefer a small, parameterized experiment with clear defaults over a new framework or broad refactor.

## Validation / acceptance criteria

1. Build and launch the app on the designated iOS simulator.
2. Capture and inspect the card with the button disabled, raised, and pressed.
3. Confirm the broad center highlight is still the card's existing highlight and visibly deforms around/across the button's raised/pressed geometry.
4. Confirm the toggle restores the card's original center content/material appearance when the button is disabled.
5. Check `git diff --check`, inspect the scoped diff, and do not include unrelated existing worktree changes in any commit.
6. Do not claim the visual goal is achieved unless the screenshots demonstrate it.

## Explicit non-goals

- A standalone button demo or a new tab devoted to a button shader.
- Only adding bevel highlights/shadows to the button edges.
- Replacing the existing center highlight with a fixed white image/gradient.
- Modifying the original archived source copy.

## Button interaction visuals
- Idle (not pressed): show only the button outline; no raised 3D depth, bevel lighting, or surface reflection.
- Pressed/dragging: enable the raised 3D form, edge highlights, and surface-following light/reflection. This effect must track the active interaction and must not remain visible at rest.
