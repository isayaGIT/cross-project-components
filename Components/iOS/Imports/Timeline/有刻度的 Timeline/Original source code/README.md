# Original source code — Peng Zhe's marked timeline

Source: https://www.pengzhe.ng/cn#timeline

This folder preserves the publicly served, compiled browser assets used by the timeline on the source website. These are **compiled production assets**, not the author's original `.astro` development source or a standalone package.

## Contents and original asset URLs

| Local file | Public source URL | Purpose |
|---|---|---|
| `js/StripTimeline.astro_astro_type_script_index_0_lang.D_Nrvdyq.js` | `https://www.pengzhe.ng/_astro/StripTimeline.astro_astro_type_script_index_0_lang.D_Nrvdyq.js` | Main tick timeline interaction/rendering |
| `js/fold-posture.CZfj1IUX.js` | `https://www.pengzhe.ng/_astro/fold-posture.CZfj1IUX.js` | Direct runtime dependency |
| `js/timeline-ready.6LI7q0eT.js` | `https://www.pengzhe.ng/_astro/timeline-ready.6LI7q0eT.js` | Timeline readiness coordination |
| `js/strip-filter-motion.DwhOPz9c.js` | `https://www.pengzhe.ng/_astro/strip-filter-motion.DwhOPz9c.js` | Direct filtering/motion dependency |
| `css/HomePage.DHZoRW9h.css` | `https://www.pengzhe.ng/_astro/HomePage.DHZoRW9h.css` | Main component/site styles |
| `css/Base.De0NOFsl.css` | `https://www.pengzhe.ng/_astro/Base.De0NOFsl.css` | Global styles and tokens |
| `css/detail-view.B50jbuj1.css` | `https://www.pengzhe.ng/_astro/detail-view.B50jbuj1.css` | Detail-view styles |

The timeline script is tightly coupled to the source site's page markup and data (`data-last-seen-root`, `data-strip`, `data-strip-track`, `data-strip-timeline`, check-in cards and timeline data). Simply opening the JS file or importing it into a blank page will not render the component by itself.

## Dependency and completeness audit (2026-10-26)

A fresh fetch of `https://www.pengzhe.ng/cn` returned the component markup and these top-level assets. The main timeline module has three static relative imports, and all three are present locally:

- `fold-posture.CZfj1IUX.js`
- `timeline-ready.6LI7q0eT.js`
- `strip-filter-motion.DwhOPz9c.js`

The main module itself has no additional static imports. This confirms the **direct JavaScript import closure of the timeline module**, not a complete standalone dependency closure.

The component is coupled to server-rendered page markup and inline page data. The HTML contains `data-strip-timeline`, `data-strip`, and `data-strip-track`, plus an inline module that seeds/render data; the main script alone does not supply that markup/data. The same page also loads `LastSeen` and `CheckinSearch` modules which interact with the same check-in records and strip. `CheckinSearch` fetches `/search.json`; the `LastSeen` scripts use additional helper modules and model assets. These are neighboring page features and are not direct imports of `StripTimeline`, but some behavior may depend on their shared page state and events.

A page-level fetch identified 12 top-level JS/CSS assets and all returned successfully at audit time. This does **not** mean all runtime assets were downloaded: model/image URLs, JSON endpoints, fonts, and any conditional requests have not been exhaustively mirrored or validated offline. The current `Preview/index.html` is still only a simplified prototype; it is not a faithful local reproduction and must not be used as proof of visual or behavioral parity.

## Live browser verification (2026-10-26)

Opened `https://www.pengzhe.ng/cn#timeline` in Chrome DevTools and verified the live page after scripts settled:

- `[data-last-seen-root]` exists and `data-expanded="true"`; `[data-strip-timeline]` exists.
- The runtime fetches `/_timeline/8286bd141ad8bd37.html` (HTTP 200, 1,652,973 bytes in this audit). The response contains one `[data-timeline-items]` wrapper and 143 `[data-checkin-id]` records. This endpoint is a material dependency that was not included in the earlier local snapshot.
- The live timeline rendered with role `slider`, keyboard focus support, and a measured box of 544 × 104 CSS px in the tested viewport. The associated strip contained 143 records.
- A synthetic `ArrowRight` key event changed `aria-valuenow` from `106` to `107` and changed the strip's `scrollLeft` from `30967` to `31162`, demonstrating a working keyboard-driven step on the live page.
- Browser network inspection showed successful HTTP responses for the main timeline script, all three direct helper scripts, the timeline HTML endpoint, the page's top-level CSS/JS, and the additional page-level helper modules observed during that load. Some `ERR_CACHE_MISS` entries were followed by successful 200 responses; no failed request for the main timeline script or timeline HTML was observed.

This validates that the **upstream site currently runs**, not that the local `Preview/index.html` works or that a local standalone reproduction is complete. The timeline payload is large and contains the author's check-in content and media references, so it has not been copied into this repository as a substitute for permission.

## License / permission status

No explicit license, source repository, or reuse/redistribution permission was verified during this audit. Publicly served production bundles can be inspected for learning, but public accessibility does not grant permission to redistribute them or claim an identical reimplementation. Keep this snapshot internal until the author (contact listed on the site: `hi@pengzhe.ng`) grants permission or a clear license is found.

## Preview

The original component is currently running in the browser at https://www.pengzhe.ng/cn#timeline. The preview relies on the upstream site because its data and page runtime are coupled to the source site; this is a visual/interaction reference, not a claim that the downloaded files are already a self-contained local app.

## Provenance and licensing

Downloaded from the public URLs listed above on 2026-10-26. The primary JS file SHA-256 is `4740b3d0985835466a12730a9d81159e4c1887ed5d069b22508fe3cb712e83aa` (verified against the live URL). No explicit license for reuse or redistribution was verified. Keep this as internal learning/reference material until the author's license or permission is confirmed. Do not treat public availability as an open-source license.
