# Workspace foundation preparation — 19 September 2026

## Start here

The owner expanded EquipSeva to three public registration purposes (biomedical engineer, hospital administrator, engineering team/organisation) and private platform operations. The governing plan and illustrated seven-page PDF are published separately in [plan PR1879](https://github.com/ganeshnaik166/equipseva-android/pull/1879). Read the root `PRODUCT_PLAN.md` on the plan branch/main before the next implementation slice. Do not treat legacy two-role or map proposals as the current product direction.

**P1 cleanup ownership and recovery remain the first live-behaviour milestone.** This commit adds unused pure preparation only. No new signup card, workspace, paid entitlement, server role, location authority or permission is shipped. Draft app PR1877 remains blocked.

## Exact revisions and scope

- Existing candidate base: `ccda4e4addef7e995f6e55a106c703dbee7af253`.
- Four-file code commit: `d202cb385d98d3ba6562b194d10294eebec0d60d`.
- Branch: `codex/quality-integration-20260919`; original coordinator/helper worktrees preserved.
- Source was frozen before GREEN and full checks. The commit was created during the full run without changing the tested files; reviewer reports pin their SHA-256 values.
- New production files: `features/auth/PublicRegistrationIntent.kt` and `core/data/location/RegionSelectionDraft.kt` under `app/src/main/kotlin/com/equipseva/app/`.
- New tests: matching `PublicRegistrationIntentTest.kt` and `RegionSelectionDraftTest.kt` under `app/src/test/kotlin/com/equipseva/app/`.

`PublicRegistrationIntent` has exactly three stable local saved keys. Unknown, privileged, legacy-role and malformed values remain unresolved; the type has no conversion to the backend `UserRole` enum or permission grant.

`RegionSelectionDraft` is immutable and only admits exact state/district pairs from the existing bundled catalog. A changed/invalid parent clears the district; selecting the same valid parent preserves it. Restore validates both values. Even a district name shared by two states is cleared on a parent change. A private constructor prevents an invalid public copy path.

The bundled catalog is legacy name data, not a newly verified LGD import. `isComplete` means a valid pair in that catalog, not an authoritative address, district code, identity or attendance claim. Preserve raw unresolved legacy location text separately in the later migration; do not use this draft to silently discard historical data.

## Test-first evidence

The RED run used compiling deliberate stubs for the two new types, not a claim of a pre-existing live app defect. Tests then passed unchanged after implementation; reviewers checked the original/current test bytes and case names.

| Run | Result |
|---|---|
| RED, new tests only | 24 tests; 14 assertion failures; 0 errors; 0 skipped. Intent: 8/3 failures; region: 16/11 failures. Exit 1. |
| GREEN, new tests plus existing compatibility controls | 45 tests; 0 failures/errors/skips. New 24 + `IndiaLocationsTest` 13 + `UserRoleEnumTest` 8. Exit 0. |
| GREEN lint | `lintDebug` passed; XML has 0 errors, 89 warnings and 2 hints. These inherited warnings are not an error-free app claim. |
| Whole-candidate unit suite | 3,699 tests; 3 failures; 0 errors; 0 skipped. The same three `SignOutCleanupLocalBoundaryRegressionTest` assertions from the base remain failing. Full command exit 1; not green. |
| Whole-candidate lint/debug | `lintDebug` and `assembleDebug` passed. |
| Design ratchet | Passed without baseline edits. First invocation failed on Windows cp1252 output encoding; process-only `PYTHONIOENCODING=utf-8` fixed the invocation, not source or policy. |
| Release/R8 | First invocation could not complete because `bash` was absent from that process PATH. The release-only rerun with installed Git Bash passed, exit 0, 5m7s, including `preReleaseCheck`, R8 and `assembleRelease`. No task was skipped. |

Commands (repository root, PowerShell, JDK 17):

```powershell
./gradlew.bat :app:testDebugUnitTest --tests 'com.equipseva.app.features.auth.PublicRegistrationIntentTest' --tests 'com.equipseva.app.core.data.location.RegionSelectionDraftTest' --no-daemon --console=plain

./gradlew.bat :app:testDebugUnitTest --tests 'com.equipseva.app.features.auth.PublicRegistrationIntentTest' --tests 'com.equipseva.app.core.data.location.RegionSelectionDraftTest' --tests 'com.equipseva.app.features.auth.UserRoleEnumTest' --tests 'com.equipseva.app.core.data.location.IndiaLocationsTest' :app:lintDebug --continue --no-daemon --console=plain

./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain
```

Full release assembly uses process-only `PRECHECK_LOOSE=1`, with Sentry upload variables unset in that process. The Windows release-only retry prepends the existing `C:/Program Files/Git/bin` and `C:/Program Files/Git/usr/bin` to the process PATH; it does not bypass `preReleaseCheck`. This is unsigned R8 validation, not a signed release, provider check or successful Sentry mapping upload. The build-slot reservation was checked before Gradle; no competing local build was launched.

The initial full command finished in 7m27s with two failed tasks: the known three unit assertions, and the missing Bash executable for `preReleaseCheck`. The failed assertions are unchanged:

- `B's outbox row survives A's delayed draft cleanup`
- `departing owner is captured before a delayed draft disk clear can observe B`
- `B's payment marker survives A's suspended outbox clear`

The corrected release command was `./gradlew.bat :app:assembleRelease --no-daemon --console=plain`. Release prerequisites are still **unaccepted**: the check reported missing `EXPECTED_CERT_SHA256` and `app/keystore.properties`, continued only under the declared dry-run mode, and observed the live assetlinks package/fingerprint. The resulting APK is unsigned: `apksigner verify` returned 1 with missing manifest signature. Sentry upload credentials were unset; no successful Sentry mapping upload is claimed.

- Unsigned release APK SHA-256: `3E603F22B10B35B6347E14CEEE6F2599C5BD35F4AAED4CAABD454330FD5A41E0`.
- Debug APK SHA-256: `F0A1AA8658894D34F706E4F12EF942F25C9B15FCD0DBB9DB9A294C6428BDAB3D`.
- Build reservation returned to FREE after all local Gradle sessions completed.

Local evidence is in `outputs/workspace-foundation-20260919/` under the task workspace: RED/GREEN logs, original RED source and XML, GREEN XML, lint XML, full log, design-ratchet output and independent reports. Logs stay outside Git; commands and results are recorded here.

## Independent bounded reviews

- [Critic](helper-reviews/codex-20260919/workspace-foundation/critic.md): **9.5/10**, no actionable finding in the four-file preparation.
- [QA](helper-reviews/codex-20260919/workspace-foundation/qa.md): **9.6/10**, no blocker in source plus targeted-test scope.

Reviewers independently checked exact files, immutable/exact-match invariants, production non-use, negative cases, positive controls, RED/GREEN hashes, 45-test XML and lint. They did not accept the app, P1, provider/device behaviour, canonical-region migration or release. The separate product-plan scores also apply only to planning.

## Next implementation and retained blockers

1. Follow the existing real mutation-boundary [sign-out ownership plan](helper-reviews/codex-20260919/signout-ownership-plan.md). Keep all reproduced failures enabled. Cover actual Room/DataStore admission, outbox/photo/payment revisions, SDK logout, realtime teardown and fresh-success controls; do not close S1 from mocks or a precheck alone.
2. Close S3 failed/cancelled logout recovery and stale router/session generations before live multi-workspace flows.
3. Build canonical tenant/site/personal-owner authority and verified region IDs before wiring the three-purpose presentation or map-free service workflow. An independent engineer's personal workspace does not require a team subscription.
4. Preserve M1 payout ordering, M3 provider classification, bound-integrity enforcement, 116 changed screenshot cases, dependency and device/provider/signing gates. Nothing in this preparation changes those files or waives those gates.

A read-only architecture recheck at `d202cb38` identified a bounded first P1 slice: synchronous immutable login/session-generation capture, then owned cleanup inside the actual `PendingAmcPaymentsStore` DataStore transform, passed from `SignOutCleanup`. Test transform admission, reverse serialization, reused order IDs, same-account relogin, A→B→A, cancellation, unknown identity and ordinary cleanup before implementation. This would protect AMC cleanup deletion only; it cannot close ownerless Room rows, other payment stores, global preferences, unowned photo producers/readers, token capture, realtime teardown or final SDK logout. The observed generation and stable SDK identity contract still need implementation tests; do not infer an active session from the request-draft lease retired on logout.

No production SQL, live account, charge, tag, app-store upload or website change was performed. Push this branch only; do not merge draft PR1877 merely because the plan was accepted.
