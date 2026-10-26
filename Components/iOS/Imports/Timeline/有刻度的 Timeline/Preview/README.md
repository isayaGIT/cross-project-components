# Browser preview

Open the original component at **https://www.pengzhe.ng/cn#timeline**.

The source site disallows embedding its page from unrelated origins (`Content-Security-Policy: frame-ancestors https://alanz.me https://www.alanz.me`), so a local iframe preview is blocked by the site's own security policy. The actual page is opened directly in the browser instead, which runs the published timeline script and its real data/runtime.

The downloaded production JS/CSS snapshot is in `../Original source code/`. **This folder is not yet a faithful reproduction.** `index.html` is a simplified prototype and differs from the source component. A faithful local harness still requires the original page markup/data, related runtime behavior, and verification of all conditional network assets; licensing/permission is also unconfirmed.


Live verification on 2026-10-26 confirmed the upstream page renders 143 timeline records and responds to keyboard stepping. This verifies the source website only; it does not validate this local prototype. See `../Original source code/README.md` for measurements and dependency details.
