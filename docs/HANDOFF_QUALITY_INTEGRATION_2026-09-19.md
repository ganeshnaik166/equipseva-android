# Quality integration continuation — 2026-09-19

**WIP. Do not merge this app candidate to main.** The audit reproduced account-cleanup failures and found further backend/payment boundaries. Passing focused tests below do not accept the app or its release. Preserve failing tests; do not raise the design baseline or replace Linux goldens with Windows renders.

## Checkouts and history

- New isolated checkout: `work/equipseva-quality-integration-20260919`, branch `codex/quality-integration-20260919`.
- Exact starting quality tip: `b453f19a1b58ca89f10a2313d34806b0ed00a471` (`origin/claudedev-quality-20260912`). Its recorded older base is `9a0ecf89c8636d926fb4744fca79b1978789c77f`.
- Preserved current main `d3a9587ba1205058cb93f0b6f07df5a547c852bf`, including screen/Content splits, RepairJobDetail decomposition, 80 component previews, 116 goldens and design lint. Integration merge: `7ae61f9a`.
- Preserved and pushed the coordinator checkout's OTP work: `0b3f02a1` and `0ff688e419ed257a4938edec60ffc1e2f11028c8` on `codex/auth-integration-20260911`. Merged here as `9a0ef7bd16630a4519a91a6cc555165e793b9965`. No reset, clean, branch switch or helper-branch force push.
- Initial regression checkpoint: `69034d84933c961e6f20c504da6f81158b9aed36` (75 tests, 42 failures; includes three Compose linkage errors, not three OTP logic defects).
- Current main CI-only merge: `e4a5e0db903fae465e8ddb2c1348d657d98f032b`, integrated here as `97f2a93b`. The app candidate is not on main.

## What actually reached GitHub/main

[PR 1876](https://github.com/ganeshnaik166/equipseva-android/pull/1876) merged **only** helper/integration push coverage for Android and secret scanning, plus an immutable gitleaks v3 pin. Exact reviewed content: `4f5a9fe28e3b30aec939088de4572061f0fe3384`. Push and PR Android and secret-scan runs passed before merge. Scoped critic 9.7/10 and QA 9.6/10 are one independent reviewer's two dimensions, not an app rating.

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

Shared UI work covers busy-sheet native Back/drag/scrim guards, exactly one selected rating, growing unread badges, small info glyphs inside real 48dp targets, and token/component reuse to satisfy the ratchet. Exact final commit and verification are recorded below when complete.

## UI test corrections must remain transparent

The first UI run included invalid fixture/oracle assumptions. A Back test compared ready-button layout against busy-button layout; the button text reflow changed sheet height. Compose 1.9.0's GetTextLayoutResult reconstructs a paragraph at parent max width while preserving the smaller text layout size, making didOverflowWidth a false clipping signal. A 14dp vector can have only three fully opaque pixels despite valid anti-aliased ink.

Corrected tests retain native dialog dispatch, visible busy bounds, physical ready dismissal, glyph dimensions, minimum 48dp targets, real touch, actual text line/character containment, exact unread semantics, and badge containment within its own tab/native viewport. Badge cases cover 3 and 4 tabs at 320dp and 1x/2x text. The old implementation must be rerun against these corrected tests before claiming the UI defects reproduced. All temporary baseline files are backed up and restored byte-for-byte in this isolated checkout.

## Open acceptance blockers and next order

1. **S1/A4 cleanup ownership:** three `SignOutCleanupLocalBoundaryRegressionTest` targets fail. A suspended draft clear can capture B's token and later erase B's outbox; suspended outbox clearing can erase B's payment marker. Read [the concrete ownership plan](helper-reviews/codex-20260919/signout-ownership-plan.md). Capture before the first suspension, then validate inside each actual DataStore/Room/stash/cache mutation boundary. Prechecks and reorder-only fixes are insufficient. Realtime removal is also topic-keyed after a suspension; a channel snapshot alone does not protect a replacement subscription.
2. **S3 cancelled-logout recovery:** keep the existing fence until a complete owned recovery or local logout. Recovery must revalidate the exact SDK login and issue fresh generations for routing/drafts/token registration; never revive old buffered links. Generic profile refresh is not this transaction. Add the root SessionViewModel + real router/host integration test before implementing.
3. **M1 payout monotonicity:** late dispatch/5xx writes can overwrite a webhook-completed payout. Fix the actual SQL transition/attempt ownership and add disposable database barrier tests; do not deploy a worker-only pre-read or run real payments.
4. **M3 provider retry contract:** actual provider outages can arrive as structured HTTP400, so treating every 4xx as permanent suppresses valid recovery. Align edge response and typed client parsing, retaining deterministic-refusal no-replay tests.
5. **Other audit risks:** ownerless outbox fairness/stale producers/readers; versioned device-token DELETE grant gap and same-token late remote revocation; pending stores/global startup reconciliation; photo URI bounded reads and busy native dismiss; locale strings; device/TalkBack/payment smoke; failed sharp web CI. Reports below give evidence and distinguish source hypotheses from executed failures.

No production migration, payment, release tag, or app-store deployment was performed. Round3822 is already applied per current main's handoff; do not reapply it. Release signing, certificate/assetlinks configuration, Sentry credentials and successful mapping upload require separate release verification. An unsigned R8 assembly is not a shipped release.

## Verification record

Local logs/XML: `outputs/quality-review-20260919/` in the parent workspace. Use JDK17 `C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot` and SDK `C:/Users/lokes/Android/Sdk`. Read `outputs/equipseva-build-slot.md` before Gradle; never overwrite another reservation. Final full check result and source commit will be appended after completion.

- Original coordinator OTP targeted bar: 28 tests, 0 failures (`otp-target.log`); original source `0ff688e4`.
- Red checkpoint: 75 tests, 42 failures (`integration-red-2.log`). Includes new targets and Compose ABI errors; not a full suite.
- Fix target 2: 113 tests, 5 failures (`fixes-target-2.log`). AMC59, push5, navigation10, OTP28 passed. Four UI oracle/behavior investigations and the newly added M6 target failed.
- UI/photo target 3: 11 tests, 3 failures (`ui-photo-target-3.log`). M6 five tests and corrected native Back passed; the remaining failures were the measured badge/icon oracle issues above.
- Design lint passes without changing baseline (raw dp2255, raw sp663, raw Button12, TextButton39). Cron response sanitization: 21 Python tests passed. No full-suite, Linux pixel, backend or release success is inferred from these focused checks.

Independent reports: [initial security](helper-reviews/codex-20260919/security-sync.md), [money/backend](helper-reviews/codex-20260919/money-repair-backend.md), [initial UI](helper-reviews/codex-20260919/shared-ui.md), [push/navigation review](helper-reviews/codex-20260919/push-navigation-independent-review.md), [AMC/SLA review](helper-reviews/codex-20260919/payment-sla-independent-review.md), [CI-only review](helper-reviews/codex-20260919/ci-only-review.md). Reports pin the source they reviewed; this handoff's later test evidence supersedes their earlier pending-execution notes only for the stated scope.
