# Welcome typography candidate — 26 September 2026

Status: **test-first RED checkpoint with unverified production implementation; GREEN, visual review and independent reviews pending**.

## Ownership and starting point

- Isolated checkout: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-welcome-typography-20260926`.
- Branch: `codex/welcome-typography-20260926`, fetched `origin/main` base `afe2bd33cdc37ca842b921c9817d75cdc645fc74` (accepted Welcome PR1888).
- Own only Welcome font resources/styles, a backward-compatible `EsBtn` label-style override used only by Welcome, focused tests and continuity docs. Leave global `EsFontFamily`, Material typography, colours, navigation, signup and session identity untouched.
- Focused unchanged-production `WelcomeTypographyTest` command: `./gradlew :app:testDebugUnitTest --tests 'com.equipseva.app.features.auth.WelcomeTypographyTest' --console=plain`, using CI placeholder local config. **6 tests / 5 failures / 1 passing default-button control**, Gradle exit 1 in 2m22s; failures are the new font/style/resource assertions, not a compile or fixture failure. Output: `outputs/welcome-typography-red-20260926.log` outside Git. The shared slot was released after the run.
- Implementation WIP uses two explicit font-family tokens for Welcome only, bundles the exact pinned binaries/notices below, changes its brand to Space Grotesk 28/34sp weight 600, body/legal/actions to Inter, and adds an optional `EsBtn.labelStyle` whose default remains the existing style. No global type/palette/auth/navigation change. This source has not yet compiled or passed its tests.

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

1. Add the two bundled fonts, explicit Welcome-only families and apply them to brand, body, legal text and both CTAs. Keep other screens' typography unchanged.
2. Run focused tests and visually inspect normal and 320×420dp/200%-font states in light and dark app themes; verify CTAs/legal remain readable and reachable.
3. Run design lint, full unit, lintDebug, assembleDebug and unsigned assembleRelease using the shared slot. Record actual counts/failures; unsigned assembly is not release approval.
4. Freeze source, request independent critic and QA review, then integrate only after their scoped acceptance and hosted CI. Three-choice registration is separate and still depends on the P2 authority contract.
