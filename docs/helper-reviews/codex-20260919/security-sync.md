# Security / sync independent review — 2026-09-19

Reviewed source: `b453f19a1b58ca89f10a2313d34806b0ed00a471`, compared with `9a0ecf89c8636d926fb4744fca79b1978789c77f`. Findings below use line numbers at that SHA. Read-only review; no Gradle, real accounts, production service calls, dependency changes or production edits were performed by this reviewer. Root requested focused synthetic regression tests next; their status is tracked separately below.

Disposition: **not accepted as closing A3/A4**. Important improvements are present, but ownership is still incomplete. No numeric acceptance score is justified before the regression cases and integration checks run.

## Findings

### S1 — P1: local cleanup can still erase the next account, and capture that account as the departing owner

`app/src/main/kotlin/com/equipseva/app/core/auth/SignOutCleanup.kt:81-112`

The first call, `fenceAndClearForSignOut()`, suspends in a DataStore edit. The token identity is read only after it returns at line 83. The subsequent Room/DataStore operations are global, suspendable wipes; no departing identity/generation is carried into their write boundaries. Moving network work to the end does not make those local suspensions atomic with authentication.

Reproduction: begin A's cleanup; hold the draft DataStore edit before completion; import/observe B and let B acquire local state; release the edit. The token capture now describes B, and the following `outboxDao.clearAll()`, preferences, stash and payment-marker wipes operate on B's state. A second case holds an outbox clear until B writes; the delayed clear then deletes B's row. `RequestServiceDraftStore` itself has an owner fence, but the rest of this sequence does not.

This is **pre-existing A4 ownership debt left open by the changed cleanup**, not a claim that all destructive operations were newly introduced. The new KDoc's “can never land on the next login's data” assertion and acceptance of A4 are nevertheless unsupported. Reordering fixes one network-wait trigger only.

Tests added by the branch mock every local wipe as immediate. `SignOutCleanupOwnershipTest`'s “B signs in” test merely releases a mocked `revoke`; it does not change an auth identity or permit a local write to suspend.

Fix direction: capture an immutable login/session owner before the first suspension, and enforce it at each actual mutation boundary (or use one shared lifecycle lock that all identity replacement and affected writers honor). A current-user check before a suspending global clear alone is insufficient. Preserve the existing draft lease fence. Add delayed local-store tests and fresh B positive controls.

### S2 — P1: captured remote token revocation still clears B's local token after the network wait

`app/src/main/kotlin/com/equipseva/app/core/push/DeviceTokenRegistrar.kt:113-125`; `core/data/dao/DeviceTokenDao.kt:17-18`

`revoke(capture)` correctly filters the remote DELETE by captured `(user_id, token)`, but after that suspendable DELETE it unconditionally runs `dao.clear()`. This removes the singleton `device_token` row even if B has registered a new token while A's request was stalled. `captureRevocation()` on B's later logout then returns null and skips the server-side revoke, leaving B's push registration behind. If a new FCM token is registered concurrently under the same account, its record is lost too.

Reproduction: real registrar, local row A, captured revocation A; hold A's HTTP DELETE; write/register B's row; release A's DELETE; B's local row becomes null. Also exercise a failed DELETE, because `runCatching` proceeds to the same clear. This is a **remaining pre-existing race inside the newly extracted API**, not a remote DELETE of B: the new remote filter itself is a real improvement.

The ownership tests replace the entire registrar with a mock, so none reaches the real trailing `dao.clear()`.

Fix direction: retire the departing local registration before network suspension with ownership/version comparison in the DAO. A token-only comparison is insufficient when A and B use the same physical FCM token; the local record needs a registration/session identity or a lifecycle-serialized compare/delete.

### S3 — P1: an unresolved refresh adopts links into a replacement account; login IDs do not identify a login generation

`app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkRouter.kt:69,78-90,135-163`; `navigation/DeepLinkHost.kt:214-216`; `core/auth/SupabaseAuthRepository.kt:34-42`

The new queue treats **every** `Unknown` as initial cold-start resolution. This branch also maps `RefreshFailure` to `Unknown`, so an already-known A can enter that state while the app retains A's UI. A route without a recipient received then goes into the pending queue and is stamped as B if the next session is B. The host accepts it because the router has just changed its owner to B. A recipient is optional, and App Links do not carry one.

Independent reproduction using the existing fake repository: observe A, observe Unknown, dispatch an allowed job/chat route with no recipient, observe B, collect; the event is `OpenRoute(route, "B")`. Cold-start Unknown -> first A should remain a positive case, but an established owner's unresolved period must retain or retire that ownership, not adopt a future account.

Also, an A event buffered before **observed** A -> B -> A survives if no host consumes it during B: only SignedOut clears the channel, and the event contains a user ID rather than a login generation. On the final A the host accepts it. This is distinct from the documented limitation of an entirely unobserved upstream boundary.

These are gaps in the **new A3 ownership implementation**. The prior router had no owner gate at all, so this is not an assertion that the old branch was safe. Server RLS still limits data access; the confirmed defect is stale/cross-login navigation, not a demonstrated server-authorization bypass.

Fix direction: distinguish initial resolution from later Unknown states; stamp immutable login generation/session identity; invalidate queued and already-forwarded events at observed identity boundaries. Add the above two cases, plus signed-out drop, duplicate email-only refresh and legitimate initial cold-start delivery.

### S4 — P2: the longer poison policy magnifies queue-head starvation

`app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:66,120,206-223`; `core/data/dao/OutboxDao.kt:14-15`

Each drain fetches exactly the oldest 25 entries. A retry leaves `createdAt` unchanged, and there is no paging/last-attempt ordering. With 25 old entries that consistently retry (for example an unavailable upload bucket while chat remains healthy), every new one-shot drain sees those same 25. A newer chat message is never dispatched. Returning WorkManager success prevents prerequisite backoff blockage, but does not solve this database selection blockage. Requiring 24 hours before poison deletion extends the starvation window from the prior attempt threshold to a day; precondition retries can remain indefinitely.

This is **pre-existing batch selection debt made materially worse by the deliberate retry-budget change**, rather than grounds to restore destructive five-attempt deletion. Fix the fairness independently: one-pass bounded pagination/claiming or a next-attempt/last-attempt ordering that gives each eligible row a turn. A regression needs the real worker selection/drain behavior with 25 blocked rows plus a 26th deliverable chat row. Pure `outboxEntryIsPoison` tests cannot establish fairness.

## Additional limits / risks; not counted as newly introduced blockers

- `CrashReporter` now replaces PII-bearing cause chains without preserving the raw causes, and bounds cycles/depth. The early identity-preserving branch at line 69 still ignores suppressed exceptions and custom `toString` implementations; no claim that arbitrary Throwable graphs are fully sanitized is justified. I did not validate the resolved reporter SDKs' suppressed-exception serialization, so this is a boundary/test gap, not a proven telemetry-exfiltration finding.
- DB recovery now explicitly discards outbox data after any failed unseal and fresh passphrase. The tests pin only which file names are deleted, not key-loss recovery. `DbPassphraseStore.kt:47-53` persists the new wrapped key before `AppDatabase.kt:79-88` deletes the old DB; a crash between them, or an ignored `File.delete()==false`, can leave a valid new key plus the old encrypted database, so the next attempt sees `mintedFresh=false` and cannot recover automatically. This is a partial recovery/atomicity risk; the old implementation already overwrote the key on unseal failure. Preserve and explicitly ratify the data-loss tradeoff; add real encrypted reopen and failure/restart tests before calling recovery verified.
- Photo handler cleanup and evidence enqueue cancellation propagation improved. Its pre-existing best-effort `appendUrlToContext` still swallows patch failures, so successful storage upload/evidence registration is not proof the job references the photo. No owner/request fencing was added around a session change during upload. Do not report A12 complete from these tests.
- `NotificationReadOutboxHandler` now defers signed-out/Unknown rather than consuming the row; its own timeout catch still cannot by type alone distinguish an outer `TimeoutCancellationException`. Structured cancellation/noncooperative repository cases are not covered by its new tests.
- `EncryptedSessionManager` no longer directly logs the session-decoding throwable, which is an improvement. The exception is still preserved as a cause for upstream code; a complete logging audit is outside this bounded pass.
- Auth OTP calls remain stateful SDK session-import operations. The new email guard and post-import UID comparison do not constitute repository-level login ownership/cancellation fencing. The coordinator owns the failing OTP work. Google-only re-auth remains explicitly unsupported.

## Changed-test review

- No ignored/deleted tests or weakened broad failure suppression found in the assigned changed tests inspected here.
- The four changed evidence-registration assertions require a CrashReporter call on permanent failure. That strengthens observability and is consistent with the revised policy; these particular four changes do **not** prove photo enqueue Retry behavior. The handoff conflates those two changes.
- The newly added token/cleanup tests prove ordering of mocks, not ownership across actual suspended writes. Router tests cover SignedOut boundaries and simple A -> B host rejection, but miss later Unknown and observed A -> B -> A. Outbox tests prove mutex exclusion and pure retry policy, not queue progress with a retrying head batch.
- No numeric score or claim of all-green tests made. Root has fresh GitHub evidence: secret scan passed at b453; backend tests passed at 55bf45; Android at 01edaee failed. Thus the handoff's categorical “none until filters land / all numbers local” is stale. Main has separately advanced and contains screenshot/design-lint gates absent from this quality branch; the “no screenshot gate in this repository” wording is not true for current main.

## Files inspected

Full source and relevant diffs: `MainActivity`, `DeepLinkRouter`, `DeepLinkHost`, `DeepLinkPolicy`, `SupabaseAuthRepository`, `ProviderReauthRequiredException`, `SignOutCleanup`, `RequestServiceDraftStore`, `DeviceTokenRegistrar`, `EquipSevaMessagingService`, `DeviceTokenDao`/entity, `OutboxWorker`, `OutboxDrainLock`, `OutboxKindHandler`, `OutboxEnqueuer`, `OutboxDao`, `OutboxErrorClassifier`, `NotificationReadOutboxHandler`, `PhotoUploadOutboxHandler`, `EvidenceRegisterOutboxHandler`, `DbPassphraseStore`, database recovery changes, `CrashReporter`, `CrashDataScrubber`, integrity probe/manifest/queries changes. Targeted context: `SessionViewModel`, main navigation event collection, `UserPrefs`, profile sign-out callers.

Tests read: `SignOutCleanupOwnershipTest`, `SignOutDraftFenceTest`, `DeepLinkRouterOwnerGateTest`, `DeepLinkHostOwnerGateTest`, `WrapScrubbedThrowableTest`, `NotificationReadDrainSessionTest`, `PhotoUploadStashCleanupTest`, evidence integration-test diff, reusable draft and Supabase harnesses. Handoff and auth/sync audits were consulted as leads, not accepted as proof.

Not exhaustively reviewed: other feature VMs and UI, money/payout/repair/backend changes (other reviewer), CI/release secrets and current GitHub runs (root), all server policies, native device behavior, actual Keystore/SQLCipher recovery, resolved reporter serializer internals, real network/provider behavior.

## Regression test drafts

Requested by root after initial findings. Draft only, outside the repository, not compiled or run yet. Exact execution result must be filled by the coordinator; no red/green claim is made from source inspection alone.
