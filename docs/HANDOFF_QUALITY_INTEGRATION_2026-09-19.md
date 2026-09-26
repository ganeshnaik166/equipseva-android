# Quality integration continuation — 2026-09-19

**WIP. Do not merge this app candidate to main.** The audit reproduced account-cleanup failures and found further backend/payment boundaries. Passing focused tests below do not accept the app or its release. Preserve failing tests; do not raise the design baseline or replace Linux goldens with Windows renders.

## Checkouts and history

- New isolated checkout: `work/equipseva-quality-integration-20260919`, branch `codex/quality-integration-20260919`.
- Exact starting quality tip: `b453f19a1b58ca89f10a2313d34806b0ed00a471` (`origin/claudedev-quality-20260912`). Its recorded older base is `9a0ecf89c8636d926fb4744fca79b1978789c77f`.
- Preserved current main `d3a9587ba1205058cb93f0b6f07df5a547c852bf`, including screen/Content splits, RepairJobDetail decomposition, 80 component previews, 116 goldens and design lint. Integration merge: `7ae61f9a`.
- Preserved and pushed the coordinator checkout's OTP work: `0b3f02a1` and `0ff688e419ed257a4938edec60ffc1e2f11028c8` on `codex/auth-integration-20260911`. Merged here as `9a0ef7bd16630a4519a91a6cc555165e793b9965`. No reset, clean, branch switch or helper-branch force push.
- Initial regression checkpoint: `69034d84933c961e6f20c504da6f81158b9aed36` (75 tests, 42 failures; includes three Compose linkage errors, not three OTP logic defects).
- Current main CI-only merge: `e4a5e0db903fae465e8ddb2c1348d657d98f032b`, integrated here as `97f2a93b`. The app candidate is not on main.
- This is a broad integration candidate, not just Claude's reported nine-commit audit: the compared branch also contains the coordinator's earlier Room/auth/UI foundation and saved historical dashboard assets. No website work or deployment was resumed. Review/integrate the bounded commits deliberately; do not treat a draft PR as approval of its entire accumulated diff.

## What actually reached GitHub/main

[PR 1876](https://github.com/ganeshnaik166/equipseva-android/pull/1876) merged **only** helper/integration push coverage for Android and secret scanning, plus an immutable gitleaks v3 pin. Exact reviewed content: `4f5a9fe28e3b30aec939088de4572061f0fe3384`. Push and PR Android and secret-scan runs passed before merge. Post-merge main Android [35434419364](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35434419364) and secret scan [35434419376](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35434419376) also passed on exact merge `e4a5e0db`. Scoped critic 9.7/10 and QA 9.6/10 are one independent reviewer's two dimensions, not an app rating.

Corrections to supplied handoff claims:

- Quality-branch CI did run: secret scan at `b453f19a` passed; Android at `01edaee` failed its unit-test step and skipped later build gates. Reported local counts do not override that failure.
- Main already has a real Roborazzi screenshot gate and design-lint ratchet. Goldens require Linux recording and review.
- September 19 daily cron workflow completed successfully (run 35430514281). This is workflow evidence, not a newly queried production ledger or proof of every scheduled slot.
- Dependabot alert 17 is open for `sharp <0.35.4` in the web console. Existing PR 1867 carries the patched lockfile but has failed web CI; it was not merged or changed. Web CI is a real gate now, not assumed historical debt.

## Implemented fixes on this candidate

| Commit | Scope | Evidence and remaining boundary |
|---|---|---|
| `a83dbedb` | Align Compose compile/runtime using enforced official BOM 2025.08.00 (Compose 1.9.0, Material3 1.3.2) | The merged graph compiled FlowRow 1.7.6 but ran 1.9.0. All three actual OTP Back/drag/scrim tests pass after alignment. Forcing old BOM failed existing accessibility APIs; the old `compose-aligned-runtime.log` is that abandoned experiment, not final version evidence. |
| `84eef630` | Retain installation token cache while revoking captured remote user/token | Five synthetic tests pass, including noncooperative late responses, shared token and signed-out control. Narrow independent critic 9.5/10. Remote grants, login ownership and complete push revocation remain open. |
| `920d185a` | Carry login-generation envelopes through router and host buffers; recheck immediate auth at delivery | Ten new tests pass for observed replacement/relogin, observer lag, clear, cold-start bound and fresh controls. Critic **9.2/10**, unaccepted: cancellation can leave a recovered same-A session fenced from fresh links. A wholly unobserved same-ID boundary remains a repository-level limitation. |
| `7c2ce0a7` | Preserve AMC proof until matching ledger success; validate actual submitted SLA hours | 59 tests pass; critic and QA test-design 9.5/10 each. Paid/null status alone cannot discard proof; trimmed positive integers reach the server without silent defaults. No provider/production payment acceptance. |
| `5b49a663` then `d8e3c77a` | Reject check-in with no decoded before-photo evidence | Unchanged real-VM target failed before fix (GPS called), then all five contract cases passed. Sheet stays open and no GPS/stash/server action begins. Independent scoped rating 9.5/10. URI decoding/size limits, upload completion and server enforcement are separate. |

Shared UI commit `3d9ee8d0` covers busy-sheet native Back/drag/scrim guards, exactly one selected rating, growing unread badges, small info glyphs inside real 48dp targets, and token/component reuse to satisfy the ratchet. All six corrected regression tests passed in the full run. Separate independent reviewers gave scoped **critic 9.5/10 and QA 9.5/10**, with QA checking the actual corrected-red/full-green XML and source equality. Linux pixel and device acceptance remain open.

## UI test corrections must remain transparent

The first UI run included invalid fixture/oracle assumptions. A Back test compared ready-button layout against busy-button layout; the button text reflow changed sheet height. Compose 1.9.0's GetTextLayoutResult reconstructs a paragraph at parent max width while preserving the smaller text layout size, making didOverflowWidth a false clipping signal. A 14dp vector can have only three fully opaque pixels despite valid anti-aliased ink.

Corrected tests retain native dialog dispatch, visible busy bounds, physical ready dismissal, glyph dimensions, minimum 48dp targets, real touch, actual text line/character containment, exact unread semantics, and badge containment within its own tab/native viewport. Badge cases cover 3 and 4 tabs at 320dp and 1x/2x text. The corrected tests were rerun against the four old production files from `69034d84` with the aligned Compose BOM: **6 tests, 6 real failures** (`ui-corrected-baseline-red.log` and archived XML). All temporary baseline files were restored byte-for-byte in this isolated checkout. The same six tests then passed against the fixed production files in the full run.

## Open acceptance blockers and next order

1. **S1/A4 cleanup ownership:** three `SignOutCleanupLocalBoundaryRegressionTest` targets fail. A suspended draft clear can capture B's token and later erase B's outbox; suspended outbox clearing can erase B's payment marker. Read [the concrete ownership plan](helper-reviews/codex-20260919/signout-ownership-plan.md). Capture before the first suspension, then validate inside each actual DataStore/Room/stash/cache mutation boundary. Prechecks and reorder-only fixes are insufficient. Realtime removal is also topic-keyed after a suspension; a channel snapshot alone does not protect a replacement subscription.
2. **S3 cancelled-logout recovery:** keep the existing fence until a complete owned recovery or local logout. Recovery must revalidate the exact SDK login and issue fresh generations for routing/drafts/token registration; never revive old buffered links. Generic profile refresh is not this transaction. Add the root SessionViewModel + real router/host integration test before implementing.
3. **M1 payout monotonicity:** late dispatch/5xx writes can overwrite a webhook-completed payout. Fix the actual SQL transition/attempt ownership and add disposable database barrier tests; do not deploy a worker-only pre-read or run real payments.
4. **M3 provider retry contract:** actual provider outages can arrive as structured HTTP400, so treating every 4xx as permanent suppresses valid recovery. Align edge response and typed client parsing, retaining deterministic-refusal no-replay tests.
5. **Other audit risks:** ownerless outbox fairness/stale producers/readers; versioned device-token DELETE grant gap and same-token late remote revocation; pending stores/global startup reconciliation; photo URI bounded reads and busy native dismiss; locale strings; device/TalkBack/payment smoke; failed sharp web CI. Reports below give evidence and distinguish source hypotheses from executed failures.

No production migration, payment, release tag, or app-store deployment was performed. Round3822 is already applied per current main's handoff; do not reapply it. Release signing, certificate/assetlinks configuration, Sentry credentials and successful mapping upload require separate release verification. An unsigned R8 assembly is not a shipped release.

## Verification record

Local logs/XML: `outputs/quality-review-20260919/` in the parent workspace. Use JDK17 `C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot` and SDK `C:/Users/lokes/Android/Sdk`. Read `outputs/equipseva-build-slot.md` before Gradle; never overwrite another reservation.

- Original coordinator OTP targeted bar: 28 tests, 0 failures (`otp-target.log`); original source `0ff688e4`.
- Red checkpoint: 75 tests, 42 failures (`integration-red-2.log`). Includes new targets and Compose ABI errors; not a full suite.
- Fix target 2: 113 tests, 5 failures (`fixes-target-2.log`). AMC59, push5, navigation10, OTP28 passed. Four UI oracle/behavior investigations and the newly added M6 target failed.
- UI/photo target 3: 11 tests, 3 failures (`ui-photo-target-3.log`). M6 five tests and corrected native Back passed; the remaining failures were the measured badge/icon oracle issues above.
- Design lint passes without changing baseline (raw dp2255, raw sp663, raw Button12, TextButton39). Cron response sanitization: 21 Python tests passed. No full-suite, Linux pixel, backend or release success is inferred from these focused checks.

### Full local check and follow-up

Clean source: **`5aaa78f073e00d82e6e211bd3ac2d548e14a3f39`**. Command: `./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain`, with `PRECHECK_LOOSE=1` for unsigned R8 validation and Sentry upload credentials unset in that process. Result: **exit 1**, 11m31s; this candidate is not green.

| Gate | Exact observed result |
|---|---|
| Full debug unit suite | **3,675 tests, 3 failures, 0 errors, 0 skipped**, across 421 classes. XML archived in `full-check-xml`; parsed totals/failure messages in `full-check-summary.json`. |
| Remaining test failures | Only `SignOutCleanupLocalBoundaryRegressionTest`: wrong departing owner after delayed draft cleanup; B's outbox erased after A's delayed draft cleanup; B's payment marker erased after A's suspended outbox clear. Ordinary-cleanup control passes. All three targets remain unchanged and enabled. |
| Shared UI and OTP | Shared UI 6/0; native OTP dismissal 3/0; existing OTP renewal contract 15/0 and gallery 8/0. The full suite also passed the targeted VM cancellation, AMC, navigation, push-cache and photo tests. |
| `lintDebug` | Initial run failed with one `UseSdkSuppress` error in the new OTP test, 89 warnings and 2 hints. Test-only follow-up `2fd157af` replaces `@RequiresApi(34)` with `@SdkSuppress(minSdkVersion = 34)`, retains explicit Robolectric SDK34, and corrects the report's resolved Material3 version. Follow-up result is recorded separately below. No lint baseline or lint suppression was added. |
| `assembleDebug` | Passed. APK SHA-256 `2A9A64F1523301BA9F1BCC389B0A4B051766474BB525C2C4A678CCB9FEC1958E`. |
| `assembleRelease` and R8 | Passed with an **unsigned** APK; SHA-256 `90FE2D9D40B20F6B5550D457FD4AA54A742E3D75E7161F7C0E7C3C353AB779C9`. `apksigner verify` correctly returned 1 / missing manifest signature. Signing/pre-release checks were warning-only, not accepted. |

The build also emitted unresolved instrumentation-class warnings for `sun.misc.Unsafe` and `androidx.compose.animation.tooling.ComposeAnimatedProperty`; successful assembly does not establish device runtime behavior. No Linux golden comparison, backend integration suite, production mutation, real payment, device/TalkBack or signed release was run in this local check. Sentry mapping upload was disabled for the check; successful symbol upload remains a release gate. No public mapping artifact was added.

Annotation follow-up at **`2fd157af`**: `./gradlew.bat :app:testDebugUnitTest --tests 'com.equipseva.app.designsystem.components.OtpRenewalDismissalTest' :app:lintDebug --continue --no-daemon --console=plain` passed in 2m24s. XML: **3 tests, 0 failures, 0 errors, 0 skipped**. Lint: **0 errors, 89 warnings, 2 hints**. Evidence: `lint-annotation-check.log`, `lint-annotation-check-xml/`, `lint-annotation-check-source-sha.txt`. Only this test annotation/report label changed after the full run; production source is identical. The full suite's three S1 failures remain unresolved, and the focused rerun is not a new full-suite green.

Fetched origin again before publishing: main remains `e4a5e0db`, quality remains `b453f19a`, both included in this candidate. The root-owned Gradle reservation was released to FREE after the follow-up completed; do not assume the slot remains free later.

Independent reports: [initial security](helper-reviews/codex-20260919/security-sync.md), [money/backend](helper-reviews/codex-20260919/money-repair-backend.md), [initial UI](helper-reviews/codex-20260919/shared-ui.md), [push/navigation review](helper-reviews/codex-20260919/push-navigation-independent-review.md), [AMC/SLA review](helper-reviews/codex-20260919/payment-sla-independent-review.md), [CI-only review](helper-reviews/codex-20260919/ci-only-review.md), [corrected UI critic](helper-reviews/codex-20260919/ui-independent-critic.md), [independent UI QA with final XML](helper-reviews/codex-20260919/ui-independent-qa.md). Reports pin the source they reviewed; this handoff's later test evidence supersedes their earlier pending-execution notes only for the stated scope.

### GitHub verification and secret-scan correction

The candidate is published as **draft [PR 1877](https://github.com/ganeshnaik166/equipseva-android/pull/1877)** at initial checkpoint `4eff9984941b63683263b6ed1ade11350ef4660a`. It remains unaccepted and must not merge to main.

- Linux Android PR run **35436516421** reproduced **3,675 tests / 3 failures**, the same enabled S1 cleanup regressions. Push Android failed too.
- Roborazzi PR run **35436516410** failed **116 of 116 screenshot cases** (generated components and hand-written screens). The downloaded artifact's digest matches GitHub, and its report confirms **116 changed, 0 added, 0 recorded, 0 unchanged**. Root and a separate reviewer visually inspected Avatar and RequestSent comparisons: typography/reflow and the new lime CTA explain visible differences in those two samples, with no obvious label loss at their rendered sizes. The other 114 remain visually unreviewed. See [the bounded diagnostic](helper-reviews/codex-20260919/screenshot-diagnostic.md); no baseline was replaced or screenshot gate accepted.
- Backend push **35436441128** and PR **35436516393** passed; this does not close the additional unimplemented payout/retry regressions.
- The old secret-scan PR success **35436516414** had incomplete coverage: a single unpaginated API page and ancestry/merge omissions. The push failure was a verified source-checksum false positive. Details and links: [coverage investigation](helper-reviews/codex-20260919/ci-history-scan-investigation.md).
- Isolated CI replacement **49b3cbec**, [PR 1878](https://github.com/ganeshnaik166/equipseva-android/pull/1878): 26 real-CLI regression tests, critic **9.5**, independent QA **9.5**. Linux secret scans passed on push **35437875937** and PR **35437909233**; its Android runs were pending when this record was written. This corrects the coverage defect without merging the app candidate.
- Exhaustive checksum triage proved all 208 findings in the original full-history comparison. The final flags produce 70 exact fingerprints, now handled individually with a [reproducible metadata-only proof ledger](helper-reviews/codex-20260919/secret-scan-evidence/README.md). New synthetic default-rule detection remains active under both CLI and helper. Final committed candidate history still requires scanning.

Only CI/policy metadata and review documentation change after `4eff9984`; Android production/tests remain the verified full-run/follow-up source. No new local Gradle run is claimed. Root-owned changes and helper work remain isolated; the original coordinator checkout is preserved.

Post-exception local scan: clean committed candidate **`509998954968854736d063eb3b753aec101b222f`**, using the actual helper from `49b3cbec` and verified CLI 8.24.3, passed with exit **0** over **all 98 commits** in `e4a5e0db903fae465e8ddb2c1348d657d98f032b..509998954968854736d063eb3b753aec101b222f`. Evidence: `candidate-history-event.json` and `candidate-full-history-scan.log` under the workspace output directory. This closes that exact local changed-history scan, with the precise 70 historical exceptions documented above; it does not close the app's S1/S3 or screenshot failures.

### Final publication checkpoint

- **Main:** CI repair [PR 1878](https://github.com/ganeshnaik166/equipseva-android/pull/1878) merged as **`6df0ec6ab1f92aaae6ac4e51e72f2c801ac51823`**, after full Android push **35437875953** and PR **35437909267**, plus both secret-scan runs, passed on exact head `49b3cbec`. The merge's Git tree equals that tested head. Main contains the two CI-only milestones (PRs 1876/1878), not this app candidate. No signed release or production deployment is claimed; a newly triggered post-merge run is separate from the completed pre-merge evidence.
- **App implementation/integration tip:** **`4fd86e5d75ced9a815f35c688bc2484340769623`**, pushed to `codex/quality-integration-20260919`. It merges the identical reviewed CI workflow/helper/tests; the single workflow conflict was the old action comment versus its replacement, resolved to exact `49b3cbec` content. Android source/build configuration is unchanged from `4eff9984`.
- **Complete-history validation on that tip:** actual helper exit **0**, **101 commits**, exact range `e4a5e0db903fae465e8ddb2c1348d657d98f032b..4fd86e5d75ced9a815f35c688bc2484340769623`. GitHub push **35438679348** and PR **35438680167** secret scans also passed. Local event/log: `candidate-final-history-event.json` and `candidate-final-full-history-scan.log`. Later documentation/main-history synchronization requires its own event scan; it does not change the app verification source.
- This final handoff/main-history merge adds documentation only to that implementation tip. The draft remains blocked by the three enabled S1 failures, S3 recovery, reviewed backend risks and 116 changed screenshot comparisons. Proceed with the owned-cleanup plan before more broad UI feature work. No tests were removed, skipped or suppressed to clear acceptance.
