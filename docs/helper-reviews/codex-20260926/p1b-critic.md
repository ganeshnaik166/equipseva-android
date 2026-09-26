# P1b independent critic review — 26 September 2026

**Scoped score: 9.6/10.** No mandatory defect remains in the declared P1b guarantee: a departing sign-out must not delete a successor login's committed Room outbox work. This is a review of code at `ed9de0c38a13e22d2c0777eaf2321cd08932e77f` on `codex/quality-integration-20260919`, compared with base `f7608644728a20bc24aa2fa74e75c3817a461fcd`. It is not whole-app security or release acceptance.

## Code finding

`SignOutCleanup` captures the immutable `LocalSessionOwnership.Ticket` before its first suspension and passes it to `OutboxSignOutCleaner`. The cleaner enters `AppDatabase.withTransaction`, checks coroutine cancellation and ticket currency after write-transaction admission, then invokes the existing suspend `OutboxDao.clearAll()` while the transaction is held. When B's login has been observed or detected by a raw identity probe before A's admission, A's ticket is rejected and B's committed row survives. An enqueue queued after A's admitted deletion cannot commit until A's transaction ends. Null, retired, replaced and observed ABA tickets retain rows. SQL failure and cancellation propagate into Room rollback. No schema, migration, producer or worker contract changed.

## Evidence independently checked

- `green-targeted-20260921`: 61 tests in 8 suites, 1 failure. All 9 new file-backed native SQLite/real Room tests and the B-outbox integration regression passed. The failure was the separate token-capture assertion.
- `full-p1b-final-20260926`: 3,743 tests in 427 suites, 1 failure, 0 errors, 0 skips. I summed the 427 XML suites independently. All 9 outbox tests passed, and the real Room B-row regression passed. The sole failure remains `SignOutCleanupLocalBoundaryRegressionTest`'s A-to-B token-capture assertion: expected A revocation, observed B revocation. The Gradle command exited 1 for that failure.
- The same final command completed `:app:lintDebug`, `:app:assembleDebug`, `:app:minifyReleaseWithR8`, and unsigned `:app:assembleRelease`. The lint report contains 0 errors, 91 warnings and 2 hints. These artifacts are not signed release or device acceptance.
- All 12 source/test hashes in the final run manifest match the reviewed files. `git diff --check f7608644 ed9de0c3` is clean. The earlier full run's extra timeout occurred in cold Room `seed()` before the B-row test body; commit `ed9de0c3` raised only that fixture's real-IO timeout from 10 to 30 seconds and corrected KDoc. It did not change behavioural assertions or production logic. The final full run passed that test.

## Open boundaries

The full unit gate is red because token capture can bind B's revocation after A's delayed draft cleanup. Do not merge the candidate as an app-wide security fix on this review. Outbox rows are historically unowned; this change does not isolate producers, readers, drainers, photo state, other local stores, realtime teardown or final SDK logout. Native SQLite/Robolectric tests do not substitute for SQLCipher and device/provider validation. Those items remain separate owned work, not defects in the stated committed-row deletion guarantee.
