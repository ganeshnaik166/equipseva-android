# Welcome typography on combined main — independent QA, 27 September 2026

**9.6/10: local scoped QA pass for Welcome typography/UI**, reviewed
at clean merged head `8a1cb2ed49193a0c38ad10f7558719cb779ef889` against
accepted main `11ac01c1d9e55439eb0673036e5589a07677e629`. Hosted CI,
main integration, physical device/TalkBack and signed release are separate
gates; this is not an app-wide score.

The app/test diff from main adds pinned Space Grotesk and Inter resources and
their OFL notices, Welcome-only typography styles, an optional `EsBtn`
`labelStyle` whose default remains `EsType.Label`, one Welcome call-site
override, and the focused typography test. It does not change SignUp, A3
deep-link source, auth/navigation or their accepted tests. The design-token
ratchet and `git diff --check` passed.

The unchanged-production font assertions were RED **6 tests / 5 expected
failures**, then focused `WelcomeTypographyTest` plus `WelcomeScreenUiTest`
passed **11/0** on the implemented source. A temporary offline visual probe
passed **4/0** and captured normal Pixel 5 plus 320×420dp at 200% text in
light and dark themes. I inspected the images: normal brand, tagline, both
actions and legal copy are legible. Compact top shows both actions and Terms/
Privacy without clipping; the full six-line tagline appears after scrolling
to it. The compact top and corrected bottom images have different SHA-256
hashes (`42c734ba…` versus `8e96c21f…`), unlike the initial ineffective
scroll-to-Privacy probe. The source gives the primary action at least 52dp
height and legal actions at least 48dp height/64dp width.

The coordinator's exact-merged-head combined Gradle run exited **0** in
9m48s. I independently counted its JUnit XMLs: **2,936 tests / 347 suites /
0 failures, errors or skips**. The lint XML has **0 errors / 87 warnings /
2 hints**; debug and unsigned release APKs are present, with R8 assembly
completed. The design ratchet exited 0. This evidence accepts the local
Welcome-only slice; the unsigned APK is not a signed or shippable release.

Light/dark image pairs are identical because Welcome pins its branded
forest/white/lime palette. This confirms readability of that fixed palette
under both theme settings but does not establish an adaptive dark design.
Robolectric pixels and semantics do not establish physical-device rendering,
TalkBack focus/order or provider-flow behavior. No mandatory source or visual
defect was found within this narrowly reviewed slice. Applicable hosted CI
must pass before main integration, and device/release claims remain open.
