# P1b — successor-login outbox deletion safety

Status: **pre-fix WIP checkpoint at the owner's usage threshold; unaccepted**. Base: `f7608644728a20bc24aa2fa74e75c3817a461fcd`, fetched and initially clean on `codex/quality-integration-20260919`. Code/test commit: `1493b870092b934d0bd0b7f10ab05631a0c74137`; later docs-only commits do not change these inputs. Draft PR1877 remains blocked. Follow [CURRENT_STATE](CURRENT_STATE.md), [PRODUCT_PLAN](../PRODUCT_PLAN.md) and the [delivery ledger](product-plan/DELIVERY_LEDGER.md).

## Scope and ownership

Coordinator owns an injected Room cleanup adapter, `SignOutCleanup` wiring, the existing local-boundary regression harness and three direct constructor fixtures, documentation, Git and Gradle. The test agent owns only a new `OutboxSignOutCleanerTest` and its uniquely named helper. Architect/QA and critic inspect independently without editing code or running competing builds. Preserve other checkouts and reserve the shared Gradle slot.

Reuse the immutable ticket already captured before the first cleanup suspension. Enter the actual Room write transaction before testing that ticket; only an admitted current ticket can delete. SQLite's writer serialization must keep B's enqueue safe whether B commits before A's admission or queues behind A's admitted deletion. A null or stale ticket retains recovery data. Keep all existing regression assertions, ordinary cleanup, and fresh current-login requests. Do not change Room v5, schema, worker or enqueue contracts.

## Required evidence

New tests precede the fix, using the production generated DAO and file-backed native SQLite under Robolectric. Prove the actual transaction admission barrier in both orders, persisted rereads, direct replacement and observed relogin/ABA, null/signed-out ownership, cancellation/rollback, database failure and fresh retry. Upgrade the older mocked outbox regression to real Room without weakening its assertions. Record any fixture correction separately from behavioural RED. Capture source hashes and exact commands; run targeted and applicable full unit/lint/debug/unsigned-release checks before bounded acceptance. Separate critic and QA reviews must meet the repository rubric; a missing review or test is not a pass.

## Limits

This is deletion safety for successor-login committed work, not complete outbox isolation. Historical rows are unowned; producers, drainers, reads, late callbacks, same-login activity and ciphertext/device verification remain separate work. Unobserved identical identity boundaries remain a ticket limitation. The token-capture regression, global scheduler/photo/preferences/realtime teardown, S3 logout recovery, payment, integrity, dependency, visual, device/provider and signed-release gates remain. Never merge this blocked candidate merely to publish continuity docs. Website work stays paused.

## Source checkpoint and resume recipe

Seven files: new `core/sync/OutboxSignOutCleaner.kt`, new `core/sync/OutboxSignOutCleanerTest.kt`, existing `core/auth/SignOutCleanup.kt`, `SignOutCleanupLocalBoundaryRegressionTest.kt`, `SignOutCleanupOwnershipTest.kt`, `SignOutDraftFenceTest.kt`, and `features/hospital/RequestServiceAccountSwitchIntegrationTest.kt`. All are under the existing production/test Kotlin trees. The adapter **deliberately still calls global `clearAll()`** so tests can demonstrate the pre-fix bug. No security fix or acceptance is claimed by the new class or parameter.

The nine new tests use separate real file-backed Room connections, actual SQLite begin/end barriers and persisted reopen. They cover both writer orderings, ordinary deletion/fresh enqueue, missing or stale tickets, observed relogin/raw identity mismatch, cancellation at admission/precommit and trigger-induced SQL failure/retry. The earlier integration test now uses real Room rather than a mocked deletion set; its five original behavioural assertions remain enabled, including token capture. Constructor-only mocking updates in three other fixtures preserve their assertions.

Architect source inspection of declared Room 2.8.4 supports the minimal fix: `database.withTransaction { currentCoroutineContext().ensureActive(); if (ownership.withCurrent(ticket) {}) database.outboxDao().clearAll() }`. `withTransaction` admits the database write transaction before invoking the block; its lock persists across the suspend DAO call. That transaction supplies serialization, while the ownership check rejects a stale departing ticket. A new synchronous DAO API/schema is unnecessary for this narrow boundary. This recommendation is not implemented or runtime-verified at this save.

On resume, read the RED evidence first. Correct any fixture failure transparently before calling it behavioural RED; preserve safety assertions. Then implement the adapter, re-run the same tests and applicable full unit/lint/debug/unsigned-release checks, inspect exact source hashes, and obtain separate critic/QA reviews. The test author is distinct from the coordinator; the architect's future QA review must disclose design input. **No P1b critic or QA rating exists yet.**

## Execution

The targeted RED command was launched before the usage threshold; it is the only new Gradle run. Evidence and source snapshots: `outputs/p1b-outbox-cleanup-20260920/red/` outside the repo, with `run-checks.ps1` in its parent. Launch HEAD was `f7608644` with the frozen edits later committed as `1493b870`. No subsequent implementation/full checks were started. Previous P1a results apply only to their recorded source, not this WIP.

Actual result: **61 tests / 8 suites / 8 failures / 0 errors / 0 skips**, exit 1, BUILD FAILED in 2m22s. All twelve recorded source/test hashes still match the launch manifest. The new class is **9 tests / 6 failures**: five expected assertion failures (B commits first; cancelled late admission; raw identity replacement; null ticket; observed replacement), plus **one unresolved `SQLiteDatabaseLockedException`** in `cancellation after real delete rolls back before disk reread and current retry succeeds`. That locking result is not behavioural RED proof; investigate the fixture/transaction unwind before implementing or claiming the cancellation case. Later branches within a test that failed its first assertion are not independently proven.

The existing real-store local-boundary class remains **5 tests / 2 failures**, the unchanged token-capture and B-outbox survival assertions. The other 47 tests pass. New ordinary/fresh-write, reverse-order transaction and SQL-trigger failure/retry controls pass. Do not call the targeted suite green. The exact command is:

```text
.\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.core.sync.OutboxSignOutCleanerTest --tests com.equipseva.app.core.auth.LocalSessionOwnershipTest --tests com.equipseva.app.core.auth.LocalSessionOwnershipFailureTest --tests com.equipseva.app.core.payments.PendingAmcPaymentsCleanupOwnershipTest --tests com.equipseva.app.core.auth.SignOutCleanupLocalBoundaryRegressionTest --tests com.equipseva.app.core.auth.SignOutCleanupOwnershipTest --tests com.equipseva.app.core.auth.SignOutDraftFenceTest --tests com.equipseva.app.features.hospital.RequestServiceAccountSwitchIntegrationTest --no-daemon --console=plain
```

Environment followed the existing JDK17/local Android setup with `PRECHECK_LOOSE=1`; no live account/provider/SQL or release operation was performed. Full unit/lint/debug/release assembly and final critic/QA review were **not run** for P1b. The task's Gradle wrapper completed and its shared build reservation was released. Preserve the failing tests and exact evidence on resume.
