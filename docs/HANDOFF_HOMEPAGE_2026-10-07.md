# WEB-H01 — public 3D homepage

## Source and ownership

- Owner-authorized public homepage only, isolated branch `codex/homepage-3d-20261007`.
- Fetched base: `49c163ebfe9bacc6b693b95a5218c9c1ac749dd8`.
- Initial implementation: `475cccea65c914ecc40d888820d97b0bde7292a0`.
- Final reviewed source: `41cdeec46266ad3a801f0dd12b836b9e343c8eb1` (narrow expanded-text-spacing fix).
- Integration: [PR1911](https://github.com/ganeshnaik166/equipseva-android/pull/1911), pending final-head checks and merge at this receipt.
- GitHub Pages is configured for `main:/docs`, custom domain `equipseva.com`, behind Cloudflare. No DNS/registrar change is needed.

## Delivered implementation

Replaces only the previous `docs/index.md` landing page with `docs/index.html`
using `layout: null`. Original procedural Three.js sculpture, SVG fallback,
lime/ink surfaces, supplied logo, locally hosted licensed Space Grotesk/Inter
WOFF2, three audience panels, approach and contact sections. The site clearly
says the app is in development. No unavailable store link, account form,
subscription checkout, invented customer statistic or testimonial is offered.

The scene supports a visible pause control, system reduced-motion preference,
hidden-tab/offscreen suspension, bounded pixel ratio and WebGL context-loss
fallback. Assets and runtime are same-origin with a restrictive meta CSP.
Build source, pinned package/lock and instructions are in `docs/homepage/`.
Generated scene: 536,869 bytes raw; the two fonts together: 89,152 bytes raw.

Unchanged: `docs/auth/**`, `.well-known/assetlinks.json`, CNAME, Jekyll global
configuration, legal pages, app/backend source, all other checkouts and Gradle
reservations. This milestone does not accept or resume any Android work.

## Verification

- `pnpm run build` and `pnpm run check`: deterministic bundle matches source.
- `pnpm audit --prod --json` and `pnpm audit --json`: 0 advisories in runtime and complete tooling dependency sets.
- Gitleaks v8.24.3 exact new-commit range from the recorded base through `41cdeec4`: 2 commits, 0 findings, exit 0.
- Both hosted Gitleaks checks on initial source `475cccea` succeeded; final receipt head remains a separate gate.
- Independent critic: **9.5/10** on final source. Desktop/mobile composition, truthfulness, source isolation and fallback reviewed; additionally checked widths 320/360/390/768/1024/1440 and final 320/360 expanded text spacing.
- Independent browser QA: **9.6/10** on final source; **34/34** functional/browser checks plus **4/4** expanded-text-spacing/reflow checks at 320/390/768/1440px; four axe scans with **0 violations**. Normal asset loads, CSP violations and runtime errors: **0 failures**. Keyboard, pause/resume, settled motion-preference changes, offscreen suspension, disabled JavaScript, denied WebGL and context-loss fallback passed.
- Before deployment, HTTPS homepage, legal routes, reset HTML/CSS/JS and app-link JSON returned 200. After deployment, repeat the live checks and compare assets to Git source before calling this live.

Evidence retained locally under `outputs/homepage-qa-20261007`,
`outputs/homepage-independent-qa-20261007`, and `outputs/homepage-critic-20261007.md`.

### Retained failed/exploratory evidence

The first Gitleaks `dir` invocation supplied two paths, causing an unintended
whole-checkout scan: **41 findings in 25 pre-existing, unchanged files**. No
finding falls in this homepage change; the changed-path comparison is recorded
locally. This is not called a clean scan and no waiver was added. The exact
new-commit scan and hosted repository-history checks are the relevant gates.

The initial browser harness had a selector setup error; a later raw run was
31/34 because it treated intentional clipped decorative artwork as document
overflow and changed emulated motion preferences without allowing Chromium to
settle. Those runs remain retained. A timed preference probe and corrected
document-overflow assertions distinguish these harness errors from product
failures. The actual focus-contrast, punctuation-contrast and narrow expanded
spacing findings were fixed in source.

`git diff --check` reports five trailing-whitespace lines inside upstream
Three.js shader template strings in the generated bundle. These are retained
verbatim from the deterministic bundler, not presented as a clean whitespace
check. No authored-source whitespace issue is claimed resolved by suppression.

## Remaining delivery and limits

1. Independent local critic/QA gates passed; require final-head hosted checks and merge PR1911.
2. Wait for Pages build/deploy success on main.
3. Verify live 3D, fonts, pause, mobile, contact `mailto:` links after Cloudflare
   transforms, and preserved legal/recovery/app-link routes.
4. Record the exact main/deploy receipt and update portable state/memory.

Reviews cover this public homepage only. Real-device/Safari/TalkBack/VoiceOver,
mailbox delivery and field-performance benchmarking are not claimed. The page
collects no form data. Meta CSP does not provide a server-level framing policy;
existing domain/edge configuration was not changed. App registration, demos,
billing, security remediation and release acceptance retain their own gates.

Design references were Awwwards' Noomo case study and interactive 3D sites;
the scene, layout and assets here are original EquipSeva work, not copied site
code or an award/affiliation claim.
