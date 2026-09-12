# Independent QA — final A2/A10 and Welcome review

Reviewed 12 September 2026 by `qa_critic_review`, candidate `codex/auth-integration-20260911`, based on `e58c48c2774a77aa0e725f1945da4e48a0fd5873`.

**QA accepts the bounded local A2/A10 slice and the separate Welcome slice, each at 9.50/10. No remaining in-scope must-fix was found.** This supersedes the preliminary pending findings. Acceptance binds to the tested source hashes below. It is not whole-auth, whole-app, device, production or signed-release approval. The separate critic's decision remains independently required.

QA independently read source/tests, reviewed scheduling and assertions, recounted preserved XML, reconciled source/APK hashes, read build/lint/signature evidence and visually inspected native-Canvas renders. The coordinator executed Gradle; QA did not run Gradle, change implementation/tests, merge or commit during this integration review. QA authored earlier root-host tests whose oracles received separate critic review; QA did not author the production fixes rated here.

## Final execution evidence

The command used Microsoft JDK 17.0.19.10, `PRECHECK_LOOSE=1` and installed Git Bash on the process PATH:

```text
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon
```

The recovered command exited **0**, `BUILD SUCCESSFUL in 4m 1s`: 134 tasks, 19 executed and 115 up-to-date. Successful unit/lint outputs were reused from the immediately preceding run of the same source. This was not a second fresh execution of every test.

QA independently recounted both `first-combined-xml/` and `final-combined-xml/`: **3,110 tests / 355 suites / zero failures, errors or skips**. Final lint contains **zero errors, 82 warnings and two hints**. The first combined run freshly executed the full suite; recovery completed the previously blocked release check/assembly.

Required final cases include session identity 56, root host 23, root destination 8, role ViewModel 23, role state 4, role UI 13, A10 status 35, notification edges 22, role tabs 8, recovery UI 2, preference fake 4, profile invalidations 3 and Welcome 11.

All **768** entries in `final-combined-source-before.json` equal `final-verified-source-after.json` and the current files independently hashed by QA. This is a manifest comparison, not 768 completed file audits. Host-only SDK escaping/Bash PATH repairs did not alter tested source.

Actual APK hashes independently recomputed:

- Debug: `f4e1aef78672e19f6232cbbec82d03a654ffbd131ae4f2faa40b3b679657f887`; 46858432 bytes.
- `app-release-unsigned.apk`: `63a9ea623ede890ff7d53ba41fadbcd81fb9eaa75d31c737f55159061e7b51ee`; 18010372 bytes.

The strict release attempt refused the missing keystore at `app/build.gradle.kts:174`. The CI-mode precheck executed successfully with its signing/configuration warnings preserved. Its historical “debug signing fallback” wording is inaccurate for this artifact: the output is **unsigned**. The coordinator's actual `apksigner verify` returned expected exit 1, `DOES NOT VERIFY`, missing `META-INF/MANIFEST.MF`; QA read that raw result. Successful compile/shrink/assembly does not establish a signed or deployable release.

The [verification manifest](verification.json) records commands, hashes, history and artifacts. Raw archives reside at `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/verification/auth-integration-20260912/`.

## Mandatory gates closed

| Area | Reviewed result |
|---|---|
| A2 R01–R05 | Actual root NavHost with inert rendering slots and explicit root VM passes isolation/admission. NeedsRole and unsupported/admin/deferred roles use the supported-role chooser; no unauthorized main/onboarding fallback. Save callbacks request authoritative refresh. |
| A2 R06–R11 | Observed account replacement/new generation retires old navigation, entry ViewModels and drafts. Same-login Unknown retains the entry while blocking interactions/focus/Back. Captured callbacks recheck live VM ownership when Compose lags. Pending and settled Back cannot resurrect displaced entries. Auth-entry cancellation and inert legacy-phone redirect pass. |
| A2 R12–R13 | Carried session/root/role, recovery and tab selectors pass in the final suite. Relevant synthetic UI hosts assert absence of production application/providers before rendering. |
| A10 observer lag | Three queued publication and three manual-admission cases cover raw B, Unknown and SignedOut ahead of the observer. An Unconfined collector records every status emission, so stale Verified cannot be hidden by a later null. Current-owner recovery succeeds. |
| A10 current auth/returned row | Immediate probes work with production-shaped mapped StateFlow. Non-replaying, suspended and failed probes fail closed without future-account work. Foreign/blank returned owners are rejected; deliberate valid retry works. The prior “never second subscription” implementation oracle was explicitly replaced before the fix by no-retained-probe/no-future-login-work. |
| A10 cancellation/revisions | Observed ABA/relogin, duplicate/email events, newest manual revision, missing/failed rows and cooperative/noncooperative completion pass. A cleared host blocks both late publication and a fresh refresh attempt. |
| Role controls | Actual glyph/button contrast passes in both themes: enabled 6.255:1, disabled/Saving 5.561:1. All 16 radio state/role/theme cases pass actual circle-pixel checks: unchecked 10.405:1, selected 5.581:1, disabled-selected 6.216:1 and disabled-unselected 6.966:1. Disabled contrast is an explicit component target. Selection, callbacks and localized reflow remain green. |
| Welcome actions/content | Four independently named actions invoke only their own callback. Public sign-in/create-account callbacks and exact legal URLs are preserved. Decorative logo, brand heading and informational role panels add no role selection or account effects. |
| Welcome reflow/localization | All six EN/HI/TE configurations pass at requested 2x font scale: 320dp portrait and 640×320dp landscape. Each complete action is individually brought into view and checked for padding, minimum dimensions, non-overlap and callbacks. All text passes full-character/no-ellipsis/height/line/semantic-bound checks. Ten Welcome entries exist per locale; the on-time-payment claim is removed. |
| Welcome visual/contrast | Eleven text items per theme pass composited glyph/surface contrast, minimum 8.313:1. QA reviewed all 12 initial/actions viewport samples across six configurations, normal light/dark views, and role/large-text examples. The 14 reviewed Welcome viewport/normal-theme files match final archive hashes exactly. Landscape endpoint snapshots do not claim simultaneous visibility of every action. |

A10 manual refresh is tested as a component endpoint; production source still has no post-KYC callsite. Its actual integration is not certified. Notification tests characterize the pure mapper, not FCM delivery, caller fallback or row/role authorization.

## Weighted scoped scores

These conservative reviewer judgments use the governing category weights, not test-pass percentages or completion estimates. Every applicable critical dimension and mandatory case passes; no average hides a failed item.

| Governing dimension | Weight | A2/A10 local | Welcome local |
|---|---:|---:|---:|
| Task correctness and completion | 25 | 9.5 | 9.5 |
| Security and privacy | 25 | 9.5 | 9.5 |
| Resilience, retained work and money correctness | 20 | 9.5 | 9.5 |
| Usability, accessibility and localization | 15 | 9.5 | 9.5 |
| Visual consistency | 10 | 9.5 | 9.5 |
| Performance and operations | 5 | 9.5 | 9.5 |
| **Weighted score** | **100** | **9.50** | **9.50** |

A2's domain gates—routing, owner/generation, callback admission, lifetime/recovery, regression and evidence—also each meet 9.5. A10's ownership/publication/cancellation obligations were independently required, not averaged against UI results.

Applicability is narrow: money movement, evidence delivery, providers and persistent form recovery are outside these slices. Welcome contains no async transaction/retained form; its resilience evidence is reflow and reachable actions. Performance/operations covers bounded probes/nonblocking cancellation where applicable, synthetic host completion/cleanup and reproducible build/guard operation, not device frame-rate/startup/network benchmarks. Accessibility ratings cover executed Compose semantics/layout/contrast; they do not establish TalkBack or universal compliance.

## Preserved failure history and rationale

- Helper history: 23-test review red with two failures; one-test delayed-auth red; then 23 A10 and 22 mapper tests green. Its 3,067-test full run preceded the final eight mapper additions; it was never an executed 3,075-test full run.
- September 12 `red-xml/`: 63 tests, 15 failures before current A10/button fixes. The earlier first glyph oracle's two translucent-color matching failures are distinguished from the genuine 2.378:1 dark-button defect. The corrected oracle requires actual composited glyph pixels and retains 4.5:1.
- Radio scope was frozen before its production fix. `ui-expanded-red-xml/`: Role UI 13/2 failures, original Welcome 11/11 failures, A10 35/0. Raw radio values reproduced 1.615:1 dark unchecked and 2.399:1 light disabled-selected. The preceding test compilation failure is separately retained.
- Welcome's first redesign run: 11/6 failures at an aggregate width flag. Diagnostic: brand line 169.819px, measured box 171px, available constraint 272px. Comparing paragraph allocation with intrinsic measured width did not establish clipping. Replacement checks retain full characters/no ellipsis/height and add actual horizontal bounds.
- Stricter checks next exposed centered paragraph/measurement disagreement (Sign in: 90px measured box, 232px paragraph, line 71–161px). Two full-width label modifiers preserve centered intent and unify the coordinate frame. All six layouts then pass strict bounds. Diagnostic 1/1 and centered 11/6 archives remain; no font/contrast reduction or ignored test was used.
- A full run stopped on ignored local SDK-property escaping; another passed all 3,110 tests/lint but could not launch Bash for the precheck. The recovered same-source run passed after host-only repair. Successful test/lint reuse is explicit.
- Raw measurement text may retain historical appended rows. Acceptance uses final passing sets and XML: last ten button, last sixteen radio and last eleven per-theme Welcome measurements. Old red rows are not relabeled as current success.

## Final source coverage

These complete files were read through the full initial read and reviewed final deltas. Full-file reading does not grant complete DeepLinkHost/A3 or whole-program security acceptance.

| File | Complete span | Final raw SHA-256 |
|---|---|---|
| `app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkHost.kt` | 1–213 | `9da63ef7ee20dffe60bf9639eebe7e29ccbf4ee532da325e5655e9fe3012eb20` |
| `app/src/test/kotlin/com/equipseva/app/navigation/DeepLinkHostEngineerStatusTest.kt` | 1–766 | `72fc63088a376dc17149c4b8147c10767db5567d55202d82452866c885e4529c` |
| `app/src/main/kotlin/com/equipseva/app/features/auth/RoleSelectScreen.kt` | 1–310 | `a4e0ebcf0b57b643528cd821d72fd4d8baa3f4c52021728c1502cc8180d7d2ed` |
| `app/src/test/kotlin/com/equipseva/app/features/auth/RoleSelectScreenUiTest.kt` | 1–483 | `cc64c66c4663d3e0cd43bdce1ff6c31dfb20c3f4afc996a9bccb9dc67de30abe` |
| `app/src/main/kotlin/com/equipseva/app/features/auth/WelcomeScreen.kt` | 1–252 | `8d84f63ce2fea9db21e07db0910c91df3357aa2286bd4b11cdf716741ddcfca0` |
| `app/src/test/kotlin/com/equipseva/app/features/auth/WelcomeScreenUiTest.kt` | 1–322 | `a40a37d9718958dc81453c348b5497fe234b27f0ac1ab3cbac2fd82cff7cec6c` |

The large resource files received **changed-span review only**, not complete-file audit credit:

| File | Reviewed span | Final raw SHA-256 |
|---|---|---|
| `app/src/main/res/values/strings.xml` | 855–864 only | `92c7bbd6e854a30532016a6aef214baab20828cb41f502c7d076c93fef13737d` |
| `app/src/main/res/values-hi/strings.xml` | 871–880 only | `781894bb31772a4b116cf8ebcd8a7ea795200667e7c6e93cfa5078a748ca265a` |
| `app/src/main/res/values-te/strings.xml` | 879–888 only | `681958bbfdeaffb496fc11f0dd5a77cb5c47feda88e2f8f8d9337328e493b974` |

Previously reviewed A2 `RootSessionHost`, `AppNavGraph`, `SessionViewModel` and `RootSessionHostTest` have no diff from saved checkpoint `1e770076`. QA verified unchanged Git blobs and LF-normalized SHA values matching the earlier review. Current CRLF raw hashes are bound by the final manifest; old raw hashes are not presented as current.

## Open program gates

A3 external intent/URI admission and buffered replay; A4 opaque repository/preference mutation ownership; A12 global cleanup/live-user token revocation; A7 signup carryover; wholly unobserved same-ID boundaries; real Auth/Storage/FCM/providers; post-KYC refresh wiring; saved-state/process restoration; native devices, TalkBack, keyboard/IME/insets, native locale rendering/native-speaker review; signed release/configuration and production verification remain open.

The root's fake signup continuation proves entry lifetime/cancellation and recoverable role re-confirmation, not actual signup SDK completion. Native-Canvas artifacts are simulated renders, not device screenshots. This is neither a 100% code audit nor M1/M2a/full-app acceptance.
