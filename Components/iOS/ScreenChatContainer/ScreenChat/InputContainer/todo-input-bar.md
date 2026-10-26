# InputBar accessory controls

- [x] Enlarge the emoji and plus icons from 16 pt to 24 pt (1.5×).
- [x] Give both circular utility buttons a visible background by default.
- [x] Overlap the two circles intentionally and render their lens-shaped intersection as a distinct visual region.
- [x] Expose the circle background, icon foreground, intersection color, and icon font through `ScreenChatConfig`, so theme presets can control them.
- [x] Add explicit colors for the built-in Midnight and other colored presets; the System preset uses adaptive semantic colors.
- [x] Record the intersection color as a required Colors token in the ScreenChat theme protocol design.

The two utility buttons remain independent accessible actions. The circle diameter is 44 pt and the overlap is 10 pt; the icon font defaults to 24 pt.
