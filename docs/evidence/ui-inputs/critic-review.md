# Independent critic review — UI-02 shared inputs

Reviewer: `/root/dashboard_critic`. Review date: 2026-09-13.

Base: `75e55c14730d6f3499d34bbcc7155e994f0f8816`.
Reviewed frozen source: `694bf690929f869277513d27f72bf24697a3d2a5`.

## Disposition

**Accepted for this local UI-02 shared-input slice at the exact frozen source above: 9.595/10.** The corrected rendering, final full-build receipt and after-build source-hash comparison have been independently checked. No remaining actionable source or inspected-render defect was found in this slice. This is not whole-app, physical-device, account-isolation, integration or release acceptance.

The scope is `EsField`, `EsDropdown`, `EsInputColors`, their focused tests and minimal caller compatibility. Production source is unchanged since `9620da6df6dea33e723cfa6e58c1b8696583afd2`; later changes strengthen test configuration, assertions and documentation.

## Historical holds and their resolution

The initial review held the usability/accessibility/localization dimension at **9.4**, despite a weighted **9.565**, because short-landscape and real large-text popup evidence was missing. A passing average cannot override a critical dimension below 9.5.

At `094000ad6fb5026cb2d144c23212bbdced87ab13`, the added popup captures were incorrectly labeled 2x. Their actual glyph sizes exposed the mismatch: the popup's separate AndroidComposeView replaced the outer test LocalDensity. The successful 3,198-test build did not establish the claimed size gate. Acceptance remained withheld. The original XML, logs and captures are archived unchanged.

Assertions on the actual popup `TextLayoutResult.layoutInput.density.fontScale` then reproduced **7 tests / 4 failures / 0 errors / 0 skips** in `xml-target-8-actual-scale-red`. The harness now sets `RuntimeEnvironment.setFontScale` before constructing the activity and popup windows and restores the prior scale at teardown. It retains native pixel, geometry, copy-completeness and callback assertions. No production workaround or reduced assertion was introduced. The corrected targeted run passed **25 tests / 0 failures / 0 errors / 0 skips** in `xml-target-9-platform-scale` (`target-9-platform-scale.log`, 59s).

The resolved Compose 1.9.0 implementation explains the prior harness error: popup content creates a new view, whose common composition locals provide that view's density. [Primary source archive](https://dl.google.com/dl/android/maven2/androidx/compose/ui/ui-android/1.9.0/ui-android-1.9.0-sources.jar)

## Independent evidence reviewed

- Read the component APIs, semantics, native keyboard/IME behavior, popup opening ownership, late/duplicate callbacks, disposal and observed value/options/enabled/searchable boundaries. Reviewed minimal fixed-light caller pairing, KYC cascading selections, payout labels, quiet-hour actions and retained ETA focus/filter behavior. No business/parser/account policy was added by this slice.
- Reviewed focused contract, native gallery and popup tests: persistent accessible names and exact errors, password semantics, current callback ownership, disabled input, hardware Enter/arrows/Escape and focus return, valid fresh selection, retired openings, actual painted borders/icons/selection/caret, growable field bodies and viewport containment. The original corrected production baseline remains **10 tests / 7 real failures**. Native IME comparisons preserve existing password/email flags without claiming OEM keyboard guarantees.
- Inspected 13 earlier native specimens spanning light, dark, fixed-light-in-dark, EN/HI/TE portrait 320dp at 2x, payout rows, selection and native popup states. These remain valid evidence for the unchanged production source within their actual tested configurations.
- Inspected the corrected `landscape-640dp-2x-popup.png`, Hindi light 2x no-match capture, Telugu dark 2x search/options capture and Telugu fixed-light-in-dark 2x no-match capture. Labels, options, focus boundaries and no-match copy remain readable. Long single-line search input scrolls horizontally as native editable input should. Menu overflow remains scrollable.
- Independently verified the corrected measurements: landscape search and selected option use actual fontScale 2.0; all twelve Indic popup option/label/value/no-match layout measurements use 2.0. English/Telugu body lines measure 42px; the Hindi font's body lines measure 53px. Telugu caret evidence contains 84 changing pixels and a 42px-high caret; Hindi contains 106 changing pixels and a 53px-high caret across five finite frames. Assertions inspect the actual popup window, not the activity image.
- Independently compared all **798** entries in `source-before-acceptedbar.json` with current files before completion and all 798 final receipt hashes after completion: zero mismatches. HEAD remained `694bf690929f869277513d27f72bf24697a3d2a5` throughout this final binding.

Raw evidence is under `work/verification/ui-inputs-20260913` beside the repository. Native captures and measurements are under `app/build/reports/ui-inputs-gallery`. The reviewer did not run Gradle or modify production/tests.

## Final verification binding

The final command was `.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon`, with `PRECHECK_LOOSE=1` and Git Bash on the process PATH. `fullbar-accepted.log` reports **BUILD SUCCESSFUL in 5m 39s**; its SHA-256 matches the receipt.

- Independently summed the archived `xml-accepted` results: **3,198 tests / 362 suites / 0 failures / 0 errors / 0 skips**. The focused slice comprises 19 contract, 18 gallery and 6 popup tests: **43 / 0 failures** within the same full run.
- Parsed the final lint XML: **0 errors, 82 warnings, 2 hints**. This is not a zero-warning codebase claim.
- Checked actual APK bytes and hashes against [verification.json](verification.json): debug **47,836,787 bytes**; unsigned R8 release **19,099,280 bytes**, below the 28MiB budget. Independently opened both APKs and verified all **10 font entries and 5 license/provenance assets** against the recorded hashes; no entry mismatches.
- The separate strict release dry run rejected the missing keystore in 9s with `PRECHECK_LOOSE` unset. `apksigner verify` rejected the unsigned artifact with `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`. Both checks recorded exit 1; their raw log hashes match the receipt. These expected failures preserve the signing limit; the unsigned artifact is not a shipped release.

Final raw XML and native captures are archived as `xml-accepted` and `gallery-694bf690`. [verification.json](verification.json), [failure-history.json](failure-history.json) and [render-manifest.json](render-manifest.json) preserve the accepted source binding and earlier failures.

## Scoped rating

These scores apply only to the reviewed local component slice and are bound to the verified final source and receipt above.

| Dimension | Weight | Score | Basis |
|---|---:|---:|---|
| Correctness | 25% | 9.6 | Preserved controlled APIs and caller behavior; native editing and valid fresh selections remain exercised. |
| Security/privacy | 25% | 9.6 | Password semantics remain native; descriptions exclude secrets; retired popup callbacks cannot publish into a later observed opening. |
| Resilience/data integrity | 20% | 9.6 | Disable/re-enable, replaced options/value, dismissal, disposal and duplicate/late callbacks are covered without silently choosing a value. |
| Usability/accessibility/localization | 15% | 9.6 | Durable names/errors, keyboard navigation, real 2x EN/HI/TE and short-landscape evidence now close the local evidence gap. |
| Visual consistency | 10% | 9.6 | Paired light/dark/fixed-parent states and actual glyph, border, icon, selection and caret rendering were checked. |
| Performance/operations | 5% | 9.5 | No added dependencies or asynchronous work; tests are synthetic and bounded. No device performance benchmark is claimed. |

Weighted score: **9.595/10**. Every applicable dimension is at least 9.5 after the corrected size evidence and final verification binding. The earlier 9.4 accessibility hold is superseded for this bounded local slice only.

## Material limits

- API34 Robolectric native rendering and synthetic hardware/IME tests do not establish physical-device TalkBack, OEM keyboard, software-keyboard inset, foldable or real-device performance acceptance.
- The component fences observed input/opening boundaries. An identity change that produces no observed component boundary remains outside its contract; A3/A4/A12 and account-ownership/security integration gates remain open.
- OTP, remaining UI-02 components, the 98-page redesign, broader localization and whole-app usability are outside this review.
- Debug and unsigned release assembly are verification artifacts. Signing, distribution, production deployment, main-branch integration and release approval remain separate.
