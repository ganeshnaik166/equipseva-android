# Handoff — reliability fixes WP22.T01, WP24.T01, WP22.T03 (Claude, 7–8 October 2026)

Branch `claudedev-reliability-20261007`, worktree `C:/Users/lokes/equipseva-reliability` on the owner's laptop. It is stacked on `claudedev-english-only-20261007` (`d8f85fcf`, WP18.T01), so it merges after that branch. Nothing here is merged and no PR is open. The live scope table is the top section of [CURRENT_STATE.md](CURRENT_STATE.md).

The tasks come from Codex's private plan (`planning/TASKS.json` and `planning/packages/WP22.md` / `WP24.md` in Codex's private work folder); they were "ready" because they depend only on PD28. Codex's own lane is stopped by the owner, so these were taken by Claude. No server, SQL or Edge change is on this branch.

## Status at a glance

| Task | Status | Key commits |
|---|---|---|
| WP22.T01 request-service submit re-entry guard (SYNC-10) | **accepted** — critic 9.6, QA 9.6 | `a67876c1` fix, `3ff28a13` review follow-up |
| WP24.T01 shared validators: Indian mobile, PIN code, UPI ID (ARCH-13) | **accepted** — critic 9.3 → 9.6 on re-review, QA 9.6 | `6db85634` fix, `834ec7c8` follow-ups, `1be63ce1` nits |
| WP22.T03 recover from a lost Keystore key without a crash loop (SYNC-07) | **built, not yet accepted** — critic 8.7 → 9.2, both blockers fixed in the final commit; QA 9.5 accept on an earlier commit | `78d9a412`, `974fa0a3`, `66d3e8b2`, final commit |
| WP22.T03 follow-up: heal installs the old code already broke | **built, not reviewed** — JVM 5/0, instrumented 2/2 on the emulator | final commit |

## WP22.T01 — no duplicate repair jobs from a double tap

`RequestServiceViewModel.onSubmit` now starts with `if (_state.value.submitting) return`. A second tap could land before the Submit button recomposed as disabled, and both taps posted a job. `RequestServiceSubmitReentryTest` (StandardTestDispatcher) holds the plan's named test `onSubmit_twiceSynchronously_createsOnce` (RED on the unfixed body: 3 tests / 1 failure), a retry after failure, an in-flight tap that must change nothing (this kills a mutant that moved the guard below validation), a successful double tap, and a success control. Not covered, by design: a retry after a lost response, process death, a missed Submitted effect — those need the idempotency key (WP22.T07).

## WP24.T01 — one rule each for mobile number, PIN code and UPI ID

- `Validators.indiaMobileNationalDigits`: "91" is a country code only after a `+` or when exactly 12 digits were typed (a bare `9123456789` used to be rejected as 8 digits); ASCII digits only; any digit from another script is refused with "Use the digits 0 to 9 only".
- `validateAddressForm` uses `Validators.indiaMobileError` and `pincodeError` (`012345` and non-mobile phones were accepted). The field is labelled "Mobile number". Behaviour change: an old address holding a landline must be changed to a mobile before it can be saved again.
- The UPI regex lives once in `Validators.vpaIsValid` (trims); `looksLikeVpa`, `vpaValid` and the founder screen's `upiPayTarget` use it, and the founder's Pay-via-UPI deeplink, label and Copy use the trimmed ID.
- RED after a pure extraction (same API, old behaviour): 9 failures in 3 suites. QA killed all seven requested mutants.
- PR #1877 (open, 661 files) also edits `Validators.kt` and `AddressFormScreen.kt`; whichever lands second rebases.

## WP22.T03 — a lost Keystore key no longer bricks the local database

**The bug.** When the sealed database passphrase could not be unwrapped, the old code minted a new passphrase but left the encrypted Room database on disk, so SQLCipher failed with "file is not a database" on the first query of every launch (outbox, device tokens) until the user cleared app data. Any Keystore hiccup took the same path and lost the queued offline writes.

**The design** (all in `core/data`):

1. `DbPassphraseStore.getOrCreate()` — unseal; anything not clearly permanent is retried once; a Keystore that is still busy (`KeyStoreException`/`ProviderException`, no permanent cause) throws without touching anything and counts a strike; the third attempt in a row is permanent. Clearly permanent: `AEADBadTagException`, `KeyPermanentlyInvalidatedException`, `CorruptSealedPassphrase`. On a mint the old Keystore key is always discarded first (`PassphraseSealer.discardKey()`), because a broken key entry fails sealing too — including on devices an older version left with no sealed copy.
2. The new passphrase is sealed at once but written to disk only by `Passphrase.commit()` (atomic temp-file + fsync + move).
3. `passphraseForDatabase()` runs the one crash-safe order: unseal or mint → `LocalDataResetNotice.markPending()` (synchronous) → delete the database, `-wal`, `-shm` and the orphaned `photo-outbox` stash → `check` the database is gone → `commit()`. A crash at any point converges on the next launch, because the old sealed copy stays until the commit.
4. `RecoveringOpenHelperFactory` (follow-up) wraps SQLCipher's factory: if the first real open still fails with `SQLiteNotADatabaseException` (the state the old code left: a new key next to an old database), it records the notice, discards the files once and opens a new database. Room opens on its own threads, never on Main.
5. The notice ("The secure storage on this phone was reset, so changes made offline that had not synced yet were lost…") is an Indefinite snackbar in `AppNavGraph`, acknowledged only when the user dismisses it. Other messages on that shared host wait behind it, which is intended for a one-time data-loss notice.

Product decision taken under the owner's standing delegation (the plan's recommended option): show the notice.

**Evidence.**

| Check | Result |
|---|---|
| RED after a pure extraction | 14 tests / 6 failures, each for the target reason |
| JVM suites at the final commit | `DbPassphraseStoreTest` 12, `DatabaseKeyLossRecoveryTest` 11, `LocalDataResetNoticeTest` 1, `RecoveringOpenHelperFactoryTest` 5 — all pass |
| Instrumented, real SQLCipher + Keystore (`eqs` emulator, Android 15) | `DatabaseKeyLossRecoveryInstrumentedTest` **2/2** |
| Device run, signed out | sealed passphrase replaced with one the Keystore rejects → database discarded, new key stored, no crash, notice shown until dismissed, nothing on the next launch |
| Mutants | "no key discard" (4 tests fail) and "commit before discard" (ordering test fails) caught; QA caught 11 of 15 of its own |
| Full bar | see the CURRENT_STATE row (recorded on the final commit) |

**Open for WP22.T03** (from QA, not blocking): treat an `android.security.KeyStoreException` cause as transient (API 33+ `isTransientFailure()`); add tests for strikes pre-seeded then cleared by a successful retry and for a header-exact truncated sealed file (`AUE=`); strengthen the "crash before commit" test. Then a critic re-check of the final commit and critic + QA of the follow-up.

## How to verify (Windows, Git Bash)

```sh
cd /c/Users/lokes/equipseva-reliability            # needs app/google-services.json + local.properties copied from the main checkout (gitignored)
PRECHECK_LOOSE=1 ./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain
# device test, emulator "eqs" running:
PRECHECK_LOOSE=1 ./gradlew.bat :app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=com.equipseva.app.core.data.DatabaseKeyLossRecoveryInstrumentedTest"
```

Traps met on this branch: do not combine `--tests` with `lintDebug` in one Gradle call (it triggers a lint tool crash on missing generated Hilt test sources); in Git Bash set `MSYS_NO_PATHCONV=1` before `adb push`/`adb shell` with device paths; `monkey` relaunches after `force-stop` silently did nothing on the emulator, use `am start -n`; the lint warning count drifts by a few with network-dependent checks — only errors matter.

## Next

1. Finish WP22.T03 reviews (above), then mark it accepted in CURRENT_STATE.
2. Owner: open the PRs in order — English-only first, then this branch (it is stacked on it).
3. Further ready plan tasks (depend on PD28 only) can follow the same pattern: scope row first, behavioural RED, fix, full bar, separate critic and QA ≥ 9.5.
