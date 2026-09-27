# Welcome typography candidate — 26 September 2026

Status on 27 September: **Welcome-only local typography and visual review accepted; latest-main integration, full build, hosted CI and device review pending**.

First saved remote WIP checkpoint: branch tip `bb867c8678a2457a2591c0612f1f37585f698913`, verified equal to local HEAD after fetch/push. The RED commit is `20be747a`, implementation `6ad6e3b3`, and bundled-license whitespace correction `bb867c86`. Current tested source tip `fc82310cedf0908e28adef3a6334d1f4236c09f6` is intentionally behind newer main and has no PR. The shared Gradle slot was released by Codex at 02:35:44 UTC after the scoped checks; re-read the slot before another build.

## Ownership and starting point

- Isolated checkout: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-welcome-typography-20260926`.
- Branch: `codex/welcome-typography-20260926`, fetched `origin/main` base `afe2bd33cdc37ca842b921c9817d75cdc645fc74` (accepted Welcome PR1888).
- Own only Welcome font resources/styles, a backward-compatible `EsBtn` label-style override used only by Welcome, focused tests and continuity docs. Leave global `EsFontFamily`, Material typography, colours, navigation, signup and session identity untouched.
- Focused unchanged-production `WelcomeTypographyTest` command: `./gradlew :app:testDebugUnitTest --tests 'com.equipseva.app.features.auth.WelcomeTypographyTest' --console=plain`, using CI placeholder local config. **6 tests / 5 failures / 1 passing default-button control**, Gradle exit 1 in 2m22s; failures are the new font/style/resource assertions, not a compile or fixture failure. Output: `outputs/welcome-typography-red-20260926.log` outside Git. The shared slot was released after the run.
- Implementation uses two explicit font-family tokens for Welcome only, bundles the exact pinned binaries/notices below, changes its brand to Space Grotesk 28/34sp weight 600, body/legal/actions to Inter, and adds an optional `EsBtn.labelStyle` whose default remains the existing style. No global type/palette/auth/navigation change. Focused `WelcomeTypographyTest` and existing `WelcomeScreenUiTest` passed **11 tests / 2 suites / 0 failures** on this source; `outputs/welcome-typography-green-20260927.log` records `BUILD SUCCESSFUL in 3m22s`.
- Static design lint exits 0 with no negative signal over baseline; `git diff --check origin/main` exits 0 after normalizing upstream licence-file trailing spaces. Neither check substitutes for GREEN or visual evidence.

## Local visual and independent review evidence, 27 September

- Temporary Robolectric/Roborazzi probe ran **4/4** (log `outputs/welcome-typography-visual-scroll-20260927.log`) with normal Pixel 5 and 320×420dp at 200% font scale; six PNGs are outside Git under `outputs/welcome-typography-*.png`. The first bottom probe scrolled to Privacy, which was already visible, so its top/bottom images were identical. The corrected probe scrolls to the full tagline; compact top SHA-256 starts `42c734ba`, bottom starts `8e96c21f`. Direct inspection finds both CTAs and legal links readable at the top and the full tagline legible at the bottom. The temporary test source was removed after the run and is not committed.
- Light/dark screenshots are identical because Welcome intentionally pins its branded forest/white/lime palette instead of reading the system colour scheme. This does not establish a separate adaptive dark treatment. Source contrast checks by the independent critic: white/forest 14.62:1, 75%-white/forest 8.80:1, lime/dark button 8.31:1.
- Independent critic **9.6/10** and QA **9.6/10** for this bounded Welcome-only local slice after the corrected scroll proof. They did not accept the whole app or release. Device TalkBack, latest-main full checks and hosted CI remain open.

## Font provenance and licensing

Official source: [`google/fonts` commit `23e54b51`](https://github.com/google/fonts/tree/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl), `ofl/spacegrotesk` and `ofl/inter`. Both `METADATA.pb` files identify OFL; read their [Space Grotesk](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/spacegrotesk/OFL.txt) and [Inter](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/inter/OFL.txt) notices. Android minSdk is 26, matching [Compose's Android O floor for bundled variable fonts](https://developer.android.com/develop/ui/compose/text/fonts#variable-fonts). The pinned downloads were prepared outside the repository before implementation:

| Candidate local file | Official source file | SHA-256 |
|---|---|---|
| `space_grotesk_variable.ttf` | `ofl/spacegrotesk/SpaceGrotesk[wght].ttf` | `acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72` |
| `inter_variable.ttf` | `ofl/inter/Inter[opsz,wght].ttf` | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `space_grotesk_OFL.txt` | `ofl/spacegrotesk/OFL.txt` | `564ce565c371c5e5bbf286006565a7c9aa55a9f56e7ca58d56e05d649dd61a72` |
| `inter_OFL.txt` | `ofl/inter/OFL.txt` | `5b9321a4298cfeb6b34354164a1c3afc3db114569984c502b9b35d988fd58c57` |

The two TTF binaries are byte-for-byte identical to the pinned downloads. The complete OFL copyright/licence text is bundled in app assets; one upstream trailing space was removed from each notice to keep the repository whitespace check clean, without changing any terms or attribution. Shipped notice SHA-256: Space Grotesk `18a4de52385f6b988782639d5d0cc1326e5a8c2de9a7f01d7b20d9aedcc60943`, Inter `5dd548d31a85f756e01d63e00d7faf1e324103ed3e9102fcbbabf2cc2db6dd39`.

## Gates to complete

1. Reconcile latest `main` after SignUp PR1892's hosted CI/merge; preserve separate SignUp and A3 acceptance records. The scoped Welcome source is frozen at `fc82310` before this integration.
2. Run design lint, full unit, lintDebug, assembleDebug and unsigned assembleRelease on the combined source using a fresh shared-slot reservation. Record actual counts/failures; unsigned assembly is not release approval.
3. Review the exact combined tree for regression, open a PR, require applicable hosted CI before main merge. Device/TalkBack verification remains a later acceptance gate. Three-choice registration is separate and still depends on the P2 authority contract.
