# P1a — AMC cleanup deletion safety

Final update 20 September 2026: **critic 9.6, QA 9.6; accepted locally for the successor-login AMC deletion-safety boundary only**. Governing plan: [PRODUCT_PLAN.md](../PRODUCT_PLAN.md). Current resume point: [CURRENT_STATE.md](CURRENT_STATE.md). Full unit execution retains two known failures, so the broader app candidate remains blocked. Publishing this handoff on main does not integrate or release the candidate app code.

## Frozen scope and ownership

- Base before code: `3c61469927b01bb0592ff501a8af42f401c937a2`, branch `codex/quality-integration-20260919`; product plan and model-continuity records merged from main without app changes.
- Frozen implementation: `434663c044460104ce7ebbc60029ac9e6ee90d28`, nine code/test files. Later documentation commits do not change this code; verify fetched HEAD and diff before resuming.
- Implementation agent owns `LocalSessionOwnership`, `PendingAmcPaymentsStore`, the AMC call in `SignOutCleanup`, two focused test classes and constructor updates in three directly affected cleanup fixtures.
- Coordinator owns the real-store upgrade of `SignOutCleanupLocalBoundaryRegressionTest`, documentation, build-slot reservation, all Gradle execution and Git. Architect/QA and critic are read-only; QA discloses its earlier design-input role. No live account, payment, SQL, UI or other cleanup-resource change is in this slice.
- Pre-slice baseline evidence: full 3,699 tests with three known cleanup failures; lint/design/debug/unsigned release passed. New P1 tests/results are recorded below; no borrowed green or score.

## Contract

Capture an immutable, independently issued login ticket as the first synchronous cleanup operation, before draft persistence or any other suspension. A valid ticket binds the current issued object, observed generation, and one SDK session snapshot's user ID plus a matching string `sub` and nonblank string `session_id`. Claims are local isolation keys, not authorisation.

The observer establishes ownership only from an agreeing signed-in event and valid raw identity. Same-session token/email changes preserve it. Initial Unknown cannot issue a ticket; established Unknown preserves one only while the raw identity still agrees. SignedOut invalidates despite cached SDK data. A raw mismatch/null/malformed identity detected by capture/guard permanently invalidates the old ticket; returning to raw A cannot revive an observed A→B→A ticket. Explicit retirement rejects the same cached login, and stale retirement cannot retire B. Another issuer's ticket or an equal-looking object is not a current ticket. An unobserved boundary with an identical final identity remains a limitation.

Pass the one ticket through cleanup to AMC `clearForSignOut`. Check it inside the actual serialized DataStore transform, surrounding both marker and proof removals in a non-suspending action. A null/stale ticket skips deletion; never fall back to a global clear. Keep filename, keys, proof encoding and unrelated payment APIs unchanged. Do not retire the ticket at cleanup entry and then expect its deletion permission to work.

The ownership monitor does not freeze SDK authentication. DataStore serialization ensures a B write queued after A's already-admitted transform survives afterward. All decisive tests must use one real file-backed store and production transform, not a mocked deletion oracle.

## Required evidence

- Ownership lifecycle: fresh success, repeated capture, token refresh, email-only change, Unknown, signed-out cached data, observed ABA, same-user new session, raw observer lag, retirement, foreign/forged tickets, blank/malformed claim shapes.
- Real store: A clear delayed before transform admission; B marker/proof committed first; same order with newer proof; observed ABA/relogin; A transform admitted first then B queued; both keys present before absence/survival assertions; persisted reread/recreation where practical.
- Cancellation/storage error propagation and fresh valid cleanup/write controls; test workers/scopes bounded and cancelled/joined.
- Existing `SignOutCleanupLocalBoundaryRegressionTest` assertions preserved. Upgrade AMC harness to the real store; token-capture and outbox assertions stay enabled even if still red.
- RED before implementation; tests unchanged for GREEN except transparently documented fixture/compile corrections. Targeted, applicable full unit/lint/debug/R8, independent critic and QA on frozen source. Do not accept from a score without required evidence.

## Limits that remain after this slice

This protects newer committed AMC data from a stale cleanup call. Global historical keys may already contain foreign-owner content; ordinary current-owner cleanup can erase those unowned historical records. This is not general account isolation. Producers, readers, `remove(orderId)`, startup reconciliation, other payment stores, Room, photos, preferences, token capture, notifications, realtime and final SDK logout remain separate boundaries. A caller already stale before invoking cleanup is not repaired by a capture at method entry. Missing reliable identity retains recovery data; it does not guess the owner.

S1/S3, money/integrity, visual, dependency, real provider/device and strict signing/release gates remain open. Draft PR1877 must stay blocked. Website work remains paused.

## Results

Initial RED compiled and ran 45 tests: 29 failures, zero errors/skips. Sixteen ownership assertions and the three original cleanup assertions failed. All ten new AMC store tests failed during setup with file-rename IO errors under plain Android JVM stubs; those ten are **not behavioural RED evidence**. The existing Robolectric SDK 34 real-store cleanup harness reached its actual three assertions and ordinary positive control.

Before rerunning RED, the AMC fixture adopted that existing Robolectric runner; its foreign-ticket case now positively obtains a separate issuer's ticket. QA requested a separate AMC assertion behind the earlier draft-disk suspension, a bounded retirement ordering check, failure after the production transform, and non-empty rejection actions. These strengthened the targets without weakening the original safety assertions.

A second run was 47/28: 26 intended failures plus two over-strict exception-object identity assertions. Coroutine exception recovery returned equivalent IOException objects; the corrected oracle requires the same class/message and the original injected failure in a bounded cause chain. All persistence, rollback, transform-count and retry checks remain.

**Final behavioural RED:** 47 tests / 26 assertion failures / 0 errors / 0 skips. Production still used the deliberately unsafe scaffold. **After implementation:** the same 47 tests / 2 failures / 0 errors / 0 skips. All six test files are byte-identical between this RED and the implementation run. The targeted command exits 1 because the two unrelated original assertions are still enabled; it is not a wholly green suite.

| Class | Tests | Behavioural RED failures | Implementation failures |
|---|---:|---:|---:|
| LocalSessionOwnershipTest | 18 | 16 | 0 |
| PendingAmcPaymentsCleanupOwnershipTest | 11 | 6 | 0 |
| SignOutCleanupLocalBoundaryRegressionTest | 5 | 4 | 2 |
| SignOutCleanupOwnershipTest | 4 | 0 | 0 |
| SignOutDraftFenceTest | 1 | 0 | 0 |
| RequestServiceAccountSwitchIntegrationTest | 8 | 0 | 0 |

The two still-failing names are `departing owner is captured before a delayed draft disk clear can observe B` (FCM token capture, not the new AMC ticket) and `B's outbox row survives A's delayed draft cleanup`. The original AMC marker assertion, new earlier-draft proof assertion and ordinary A cleanup control pass.

Targeted command:

```text
.\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.core.auth.LocalSessionOwnershipTest --tests com.equipseva.app.core.payments.PendingAmcPaymentsCleanupOwnershipTest --tests com.equipseva.app.core.auth.SignOutCleanupLocalBoundaryRegressionTest --tests com.equipseva.app.core.auth.SignOutCleanupOwnershipTest --tests com.equipseva.app.core.auth.SignOutDraftFenceTest --tests com.equipseva.app.features.hospital.RequestServiceAccountSwitchIntegrationTest --no-daemon --console=plain
```

Full checks ran on the same frozen implementation:

```text
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain
```

| Check | Actual result |
|---|---|
| Full unit | **3,729 tests / 425 suites / 2 failures / 0 errors / 0 skips**; only the two names above |
| lintDebug | Passed: 0 errors, 89 warnings, 2 hints |
| assembleDebug | Passed |
| assembleRelease / R8 | Passed, unsigned local APK |
| Design ratchet | Passed, baseline unchanged |
| Combined command | Exit 1, BUILD FAILED in 7m54s because the two unit assertions remain red |

All nine code/test file hashes still match the frozen launch manifest. Relative to the prior 3,699-test baseline, 30 tests were added and the original AMC cleanup regression was fixed; no failing test was removed, ignored or relabeled. No UI source changed and no new screenshot/device claim is made.

Build environment: JDK 17.0.19, installed Android SDK, installed Git Bash on process PATH, `PRECHECK_LOOSE=1` for this unsigned local check. Sentry credential variables were removed only from this process, so its upload remained credential-gated. **The existing Crashlytics Gradle finalizer reported a mapping-file upload.** That log is not an independently verified symbol-delivery receipt or a release acceptance. No account/payment operation, production SQL, release tag or app-store upload was performed.

`apksigner verify --verbose app/build/outputs/apk/release/app-release-unsigned.apk` returned 1 (`DOES NOT VERIFY`, missing manifest signature). This is the expected unsigned result, not signing approval. Strict signing, certificate, Sentry, provider/device and release acceptance remain open.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| app-debug.apk | 49,129,496 | `0438A7D672359BBEBE2FC440A6D871956659B80703675D592CD32D5B7EC174C9` |
| app-release-unsigned.apk | 19,185,833 | `D071FAF6CDD1B5BFBA76337DFBEBB4B799928FC980DD5BB10CFE226F2086D633` |

External logs/XML/source snapshots and commands are under `outputs/p1a-amc-cleanup-20260919/` in `red`, `red-corrected`, `red-behavioral`, `green-targeted` and `full`; all test accounts/payment proofs are synthetic. `full/verification.json` summarizes the checks. The shared Gradle reservation was released after that wrapper finished, then reacquired for the test-only review polish below.

## 20 September — QA-driven test-only polish

Initial critic review was 9.5; QA was **9.3, unaccepted**. Its four concrete gaps were direct throwing identity probes in both APIs, cancellation propagation/recovery in both APIs, guard-action failure with separate-thread monitor reuse, and proof persistence read from reopened disk before a later write could conceal loss. Initial reports are preserved in the external evidence directory; a score was not raised merely to satisfy the threshold.

Test-only commit: `8d80ba3c85a9dd833d08930f8b7728f9c485247c`. The new `LocalSessionOwnershipFailureTest` has five tests. The existing AMC cancellation case retains its original assertions and additionally closes/reopens the real file immediately after cancellation, compares exact marker/proof/unrelated values, then recreates a writer and proves both old recovery data and fresh B work persist. The two known token/outbox regression tests are untouched. All three production hashes still equal `434663c0`.

The seven-class targeted command is the earlier targeted command plus `--tests com.equipseva.app.core.auth.LocalSessionOwnershipFailureTest`. It executed **52 tests / 7 suites / 2 failures / 0 errors / 0 skips**, exit 1. New failure tests are 5/0; strengthened AMC tests are 11/0. Only the original token/outbox names above fail. Evidence: `polish-targeted/`. Its launch HEAD was `434663c0` with the two frozen test edits; all ten source hashes were verified unchanged before committing those same edits as `8d80ba3c`. These are disclosed review additions after implementation; they are not claimed as part of the original unchanged RED/GREEN test set.

Full-unit verification at this frozen test commit executed **3,734 tests / 426 suites / 2 failures / 0 errors / 0 skips**, exit 1, BUILD FAILED in 3m36s. Only the same two token/outbox assertions fail. The command is `.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain`, archived in `polish-full-unit/`. All ten source/test hashes match the targeted and full-unit launch manifests. Compared with the 3,699 baseline, 35 tests have been added and none removed or disabled.

Lint/design/debug/unsigned R8 evidence above remains the earlier execution on identical production/build source; it is not a newly executed assembly or lint of the test-only commit. The shared slot was released after the wrapper completed; no Gradle process remains owned by this task.

Final [critic review](helper-reviews/codex-20260919/p1a-critic.md): **9.6/10** (weighted 9.62; applicable critical dimensions 9.7/9.6/9.7). Final [QA review](helper-reviews/codex-20260919/p1a-qa.md): **9.6/10**, all applicable critical dimensions 9.6. Both independently inspected the frozen diff, source hashes and actual XML/log evidence. UI/visual are not applicable. QA's earlier design participation is disclosed in its report; it is separate from the implementer and critic, not a design-blind review. Initial critic 9.5 and QA 9.3 reports remain preserved externally. The increase follows the named test evidence, not a waiver of the gate.

Both reviews accept only the deletion-safety boundary described here. Global payment confidentiality, historic unowned data, other cleanup resources, the two retained failing tests, broader app integration and release remain unaccepted. Next P1b has not started.

## Files and merge points

The nine files in [code commit 434663c0](https://github.com/ganeshnaik166/equipseva-android/commit/434663c044460104ce7ebbc60029ac9e6ee90d28) are:

- New `core/auth/LocalSessionOwnership.kt`; existing `core/auth/SignOutCleanup.kt` and `core/payments/PendingAmcPaymentsStore.kt` under the production Kotlin package.
- New `core/auth/LocalSessionOwnershipTest.kt` and `core/payments/PendingAmcPaymentsCleanupOwnershipTest.kt`.
- Real-store upgrade and one new case in `core/auth/SignOutCleanupLocalBoundaryRegressionTest.kt`.
- Constructor dependency only in `core/auth/SignOutCleanupOwnershipTest.kt`, `core/auth/SignOutDraftFenceTest.kt` and `features/hospital/RequestServiceAccountSwitchIntegrationTest.kt`.

Preserve the captured ticket at cleanup entry and the guard inside the actual AMC transform when integrating other cleanup work. No Room schema, auth repository, navigation, role UI, build policy or dependency change belongs to P1a. The broad draft PR1877 must not merge because this bounded component passes.

Next: **P1b real Room outbox cleanup deletion safety**. Write both transaction-admission orderings against the actual Room database, retain ordinary cleanup and fresh enqueue controls, and validate the existing ticket only after entering the write transaction. Keep the token-capture regression visible; owned token capture and all logout callers/final SDK logout need separate orchestration work. Historical unowned records, same-current-login new activity, global reads/writes and unresolved confidentiality remain outside the deletion-only contract.
