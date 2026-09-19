# UI-02 shared inputs: independent QA receipt

Reviewed 2026-09-13. **Bounded local QA disposition: accepted, 9.58/10.** Each applicable dimension reaches 9.5, and no mandatory local gate remains unverified. This is the QA reviewer's disposition; the independent critic and coordinator retain their separate decisions. This is not whole-app, complete UI-02, device, authentication, security-program, or release acceptance.

Frozen application/test source: `694bf690929f869277513d27f72bf24697a3d2a5`, based on `75e55c14730d6f3499d34bbcc7155e994f0f8816`. Production source has not changed since `9620da6df6dea33e723cfa6e58c1b8696583afd2`; subsequent changes correct tests and evidence descriptions. The coordinator ran Gradle. QA independently reviewed source and native images, recounted archived XML, recomputed source and artifact hashes, and inspected the actual APK contents without running competing builds or modifying implementation.

## Scoped scoring

The fixed master-plan weights are retained. These are bounded reviewer judgments supported by the gates below, not mathematical proof of app quality or a conversion of test counts into a score.

| Dimension | Weight | Score | Basis within this slice |
|---|---:|---:|---|
| Correctness | 25% | 9.6 | Actual editable/popup contracts, exact controlled values, callback counts, named quiet-hour action, keyboard and caller compatibility checks. |
| Security/privacy | 25% | 9.6 | Password masking/name separation, actual native input flags compared with unchanged baseline, disabled IME rejection, and retired dropdown callbacks cannot publish into a later observed context. No new persistence or network effects. |
| Resilience/data | 20% | 9.6 | Disable/re-enable, empty/replaced options, value ABA, query retirement, repeated selection, disposal, and stale opening/IME callbacks have discriminating checks. |
| Usability/accessibility/localization | 15% | 9.5 | Durable names/errors, growable targets, actual focus/selection/caret pixels, native keyboard paths, EN/HI/TE large text, genuine platform-scaled popup and short-landscape reachability. |
| Consistency | 10% | 9.6 | Complete semantic color pairs and explicit fixed-light compatibility, approved type/shape, localized copy, and tested placeholder/icon/error/disabled states. |
| Performance/operations | 5% | 9.5 | Bounded component state, isolated and restored test-window configuration, unchanged-source regression/build receipts, intact packaged assets and release size budget. This does not certify device latency or memory benchmarks. |
| **Weighted result** | **100%** | **9.58** | All mandatory local gates passed. |

## Independently reconciled final evidence

Raw evidence is outside the checkout at `../verification/ui-inputs-20260913/`.

- `fullbar-accepted.log`: **BUILD SUCCESSFUL in 5m 39s**, 134 tasks: 20 executed, 114 up-to-date. Command includes unit tests, lint, debug assembly and unsigned release/R8 assembly. Reused tasks are not represented as fresh execution.
- Parsed all **362 archived suites in `xml-accepted/`: 3,198 tests, zero failures, errors or skips**. Every archived XML hash matches `verification-accepted.json`. The final three input suites contain **43 tests: 19 contract, 18 gallery, 6 popup**, all green.
- All **798 raw source-file hashes** in `source-before-acceptedbar.json` still match the reviewed files. The source manifest SHA-256 is `8d0264cd263ded2a9e849f79ec4872338f44efe22c20d73b0ede8116482fdc8f`.
- Independently parsed final lint XML: **0 errors, 82 warnings, 2 hints**. This is not a zero-warning build. Lint XML SHA-256: `ac7f46abec07beb0eccbcd96e36ccd950d70b23600aec4039ece9202cb61de97`.
- Final build log SHA-256: `5a2790bde18305c22b4c17a6de1ba3999496a0f5ce2e3bdb9d78a99a57b92abb`. Verification receipt as inspected: `96c855ecbff12c996b82defcfa8ef5613b7227cfdd2d189b61ae59155363d3fa`.
- Debug APK: **47,836,787 bytes**, SHA-256 `991f4bf6a60a56ed4c2a4f8304f355dc46c7b932a64b5778072f980a2cc75826`.
- Unsigned release APK: **19,099,280 bytes**, SHA-256 `c187224eb16cfef31c4c34af4325687bf6e2d568487b2dcc6f1ab79f21c712f4`, below the 28 MiB budget. Independently compared all **10 packaged font byte hashes and 5 licence/provenance assets in each actual APK** with source: no missing or mismatched entry, including renamed release resources.
- `unsigned-verification.log` says **DOES NOT VERIFY / Missing META-INF/MANIFEST.MF**. `strict-release.log` refuses release without the keystore when the loose CI setting is absent. Its historical wording about debug signing is not the artifact's status: the generated release is unsigned and is not approved for distribution.

## What the focused evidence proves

The tests execute the production `EsField`, `EsDropdown`, color helper and `QuietHourField` inside an isolated plain Application using actual Compose resources. They preserve password semantics, optional latest IME callbacks, Next focus, disabled editor-action rejection, the caller's focus modifier and numeric filter. Quiet-hour tests exercise the real wrapper's physical input-area tap and its single enabled, named accessibility action; they do not claim a production time-picker workflow was run.

Dropdown tests exercise the real focusable popup, actual hardware-style key dispatch and native PopupLayout Escape separately from IME actions. They distinguish an opening from subsequent openings, retire observed value/options/enabled/searchable contexts, reject old callbacks and preserve caller-owned selection. These are component context boundaries, not proof of repository account fencing.

Native pixel checks cover paired normal/error/disabled text, placeholders, icons, selection fill and glyphs, focus boundaries, popup options/search/empty copy and the changing caret across five finite frames. The popup is captured from its own Android window rather than an activity bitmap. Expected popup activation is delivered explicitly and restored at teardown; no production focusability workaround was added. Text checks require complete visible characters, no ellipsis or height overflow, measured line bounds and contained semantic bounds. Pixel and layout checks are not a general proof of every glyph's ink on every device.

QA visually inspected the corrected Hindi light, Telugu dark and Telugu fixed-light popup captures, the 640x320 landscape popup, Hindi dark and Telugu fixed-light long-field views, and dark selection/icon rendering. Labels, values, options and errors are readable in these specimens; the landscape case performs the real searched option selection. A long single-line search value scrolls horizontally as expected.

## Preserved failures and the actual-density correction

The corrected original baseline recorded **10 tests / 7 failures** on unchanged production. Subsequent evidence retains the invalid selector, native keyboard harness corrections, floating-label large-text defects, unnamed quiet-hour action, and popup activation diagnostics. Native EditorInfo preserves the actual baseline password `0x81` and email `0x21` variations without autocorrect/capitalization flags; an earlier unsupported NO_SUGGESTIONS assertion was removed with its failure retained. No OEM keyboard suggestion-storage guarantee is inferred.

The `094000ad` revision passed 3,198 tests but its new popup images were incorrectly labelled 2x: the parent LocalDensity did not govern the popup's separate AndroidComposeView. QA found identical 24px line/caret metrics in the alleged 1x and 2x images and withheld acceptance. The old XML/images remain archived in `xml-094000-pre-scale-fix/` and `gallery-094000-pre-scale-fix/`; those images count only as ordinary-size popup evidence.

Discriminating assertions on the actual popup TextLayoutResult density reproduced **7 tests / 4 failures**, all requested 2.0 versus actual 1.0, in `xml-target-8-actual-scale-red/`. The harness now calls `RuntimeEnvironment.setFontScale` before constructing the host and popup, then restores prior scale in teardown. The unchanged density/containment/pixel assertions pass in **25 tests / zero failures** in `xml-target-9-platform-scale/` and again in the final full suite. Actual layout density is 2.0: body/caret height is **53px for the Hindi specimen and 42px for English/Telugu** on API34; landscape search and option also report 2.0. Main-window synthetic LocalDensity stress and actual platform-scaled popup evidence are distinguished. No production change was needed to close this test-configuration gap.

## Source review coverage

Complete files reviewed, including final test deltas; ranges are inclusive. Caller changes received changed-span/behavior review rather than a claim that every caller file or page was fully audited.

| File relative to checkout | Lines | Final SHA-256 |
|---|---:|---|
| `app/src/main/kotlin/com/equipseva/app/designsystem/components/EsField.kt` | 1-132 | `6b1150dcb36c7eb35bb0a5aecf33602a7a53a023b8f0b877ec59cb3260c784f5` |
| `app/src/main/kotlin/com/equipseva/app/designsystem/components/EsDropdown.kt` | 1-144 | `a3336792279cc70094dcab927bf6a87a221e068c49572c123c05caaab143ab2a` |
| `app/src/main/kotlin/com/equipseva/app/designsystem/components/EsInputColors.kt` | 1-30 | `7c1199d56a04eebc3939af2da50efb7431d0444873c7567859517396520dbfe2` |
| `app/src/test/kotlin/com/equipseva/app/designsystem/components/SharedInputContractTest.kt` | 1-469 | `7ff942445d1dd7dc7066505f876cad697fb3e7b4a6d657604cdac6ec893d2bc1` |
| `app/src/test/kotlin/com/equipseva/app/designsystem/components/SharedInputGalleryTest.kt` | 1-522 | `c025aa265d30d068337cd87b47aefb06e265780f50cfc2371d91670ffcc53304` |
| `app/src/test/kotlin/com/equipseva/app/designsystem/components/SharedInputPopupGalleryTest.kt` | 1-298 | `dea0d44a2a2b9dd931aec2ff2fcce873e12576cc8c2b1a51156d4bd365acae16` |

## Limits retained

Focused input rendering is local Robolectric/API34 evidence. Physical-device/OEM IME behavior, TalkBack traversal, actual keyboard insets, process restoration, performance benchmarks, all supported Android versions and every real caller page remain unassessed here. Default-theme preference persistence was covered by the prior foundation work and broad regression suite; this slice does not re-certify all page themes. The source inventory's fixed-light compatibility is not an end-to-end run of all 57 original field and 3 dropdown instances.

Authentication/provider integration, A3/A4/A12, account boundaries invisible to the component, network/storage/money contracts, remaining shared components, the 98-page redesign, main integration and signed release stay outside this acceptance. No full-app security score, exhaustive whole-code audit completion or claim that every bug is fixed is made.
