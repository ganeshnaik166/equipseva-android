# Handoff — `claudedev-quality-20260912` (full code-quality audit + fixes), 2026-09-12

**Status: PAUSED by the founder at ~03:20 UTC ("token consumption is too high, save everything").**
Branch `claudedev-quality-20260912`, isolated worktree `C:/Users/lokes/equipseva-quality-20260912`.
Base: `a9b35f3c` = `origin/codex/helper-engineer-status-20260911` (Codex A2 WIP tip `1e770076` + the GPT-5.3 helper's A10).
Baseline verified on the untouched base in this worktree: `:app:testDebugUnitTest :app:assembleDebug` → BUILD SUCCESSFUL,
**3,075 tests / 353 suites / 0 failures** (4 m 25 s). Local ignored configs (`local.properties`, `app/google-services.json`)
were copied from the main checkout — a fresh worktree fails `processDebugGoogleServices` without them.

Founder's instruction (2026-09-12): "check fully code quality and in a separate branch implement all the code changes
required, find all the bugs". Rules kept: never touch the Codex coordinator's checkouts; additive, test-first; commit+push
every milestone; the Gradle slot file was reserved transparently (its previous holder had no Gradle process for 17 h) and is
released again by this pause.

## What is in this commit (m1)
| File | State |
|---|---|
| `app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkPolicy.kt` | NEW, pure. External-route allow-list: fixed notification landings (home, profile, profile/kyc, notifications, engineers/directory, engineer/amc_visits) + strict-id routes (repair/detail/{RPR-n\|uuid}, chat/detail/{uuid}, engineers/public/{uuid}, amc/contract/{uuid}); denies founder/*, root_*, auth*, onboarding, security/*, profile sub-forms, query strings, `%`/`#`/`?`/`\`/whitespace. `isPrivileged()` helper. **Not yet wired** into `DeepLinkRouter`. |
| `app/src/test/kotlin/com/equipseva/app/navigation/DeepLinkPolicyTest.kt` | NEW, 4 tests. **Not yet executed** (Gradle not run after writing). |

Nothing else changed. No production behaviour differs from the base yet.

## Audit status — what was found, what was NOT
Seven read-only audit agents were launched (auth/session/navigation; core/data+DTO↔SQL; repair/hospital/mybids/chat;
AMC/earnings/payouts/KYC/profile; sync/security/observability/build/CI; Compose UI + design system + locale placeholders;
SQL rounds 3816–3823 + edge functions). **They were killed by the pause before reporting — no findings were received.**
Re-run them (same seven scopes, output format: ID / severity / file:line / what / evidence / fix / test) when resuming.

Findings already in hand (from the 2026-09-11 review branch `claudedev-next-review-20260911` and the coordinator's own
integration notes), verified against source in this worktree:
| ID | Sev | Where | Defect |
|---|---|---|---|
| A3-01 | HIGH | `DeepLinkRouter.dispatch` L38-44, `MainActivity` L63/L106, `MainNavGraph` L218-232 | `EXTRA_ROUTE` from ANY explicit intent to the exported activity is navigated verbatim (founder/* UI, payout/email/password screens reachable from a third-party app). |
| A3-02 | HIGH | `DeepLinkRouter` L35 (singleton buffered channel, no clear), `DeepLinkHost` L170-181, `SignOutCleanup` (no tray cancel / router clear) | Deep links replay across A→B and A→SignedOut→A; nothing gates on the session. |
| A3-03 | MED | `MainActivity.onCreate` L63 | Dispatches the launch intent on every recreation (no `savedInstanceState == null` guard) → duplicate navigation after process restore. |
| A4-01 | HIGH | `SignOutCleanup.wipeLocalUserState` L53-96 | Every step `runCatching` (swallows CancellationException); the slow network `revoke()` runs SECOND, before the global wipes — a stalled revoke lets the wipes land on the NEXT login's outbox/stash/pending-payment markers/prefs/realtime channels. |
| A4-02 | HIGH | `DeviceTokenRegistrar.revoke()` L89-104 | Reads `auth.currentUserOrNull()` at run time, not at sign-out start → a late revoke deletes the next user's `device_tokens` row (same FCM token). |
| A4-03 | MED | `ProfileViewModel.onSignOut` L592-608 + `deleteAccount` L559, `SessionViewModel.signOutFromGate` L276-306 / L402 | Two sign-out implementations; `runCatching { wipe }` in Profile swallows cancellation. |
| AX-01..11 | LOW/MED | Welcome/SignIn/SignUp/Profile (GPT-5.3 inventory `docs/GPT53_ACCESSIBILITY_INVENTORY.md`) | Fixed-height CTAs, clickable-without-role, 3.7:1 "or" text, 4-line error cap, etc. |
| coord-1 | — | `A3_deep_link_security_contract.md` §3 cold-start row vs T-A3-02c | Contract inconsistency: "at most one pending event" vs "two events in order". Resolution chosen below (queue ALL events dispatched while auth is Unknown, in order). |

## Designed fixes (ready to implement — no code written yet beyond DeepLinkPolicy)
1. **`DeepLinkRouter`** takes `AuthRepository` (+ an injectable scope; secondary `@Inject` ctor). `stateIn` the session.
   `dispatch(intent)` → pure `dispatchRoute(route, recipientUserId)`: `EXTRA_ROUTE` accepted only if
   `DeepLinkPolicy.isExternallyAllowed`; https path via `routeForParts` unchanged. Events become
   `OpenRoute(route, ownerUserId)`. While the session is `Unknown` (cold start), routes queue in order and are stamped when
   the first `SignedIn(U)` arrives; on `SignedOut` the queue AND the channel buffer are cleared (proposed default for owner
   question O1 = drop). A recipient extra (`EXTRA_RECIPIENT_USER_ID`, set by the FCM service from `data["user_id"]` when
   present) that mismatches the current user drops the event (identity de-dup, not authorization). `clear()` public.
   Denials logged without PII. Existing `DeepLinkRouterTest` only uses `routeForParts` — unaffected.
2. **`DeepLinkHost`** router-collector (my section, lines 170-181 — NOT the coordinator's engineerStatus section): forward
   only when `event.ownerUserId == liveUser` (a separate `stateIn` of `sessionState`), else drop.
3. **`MainActivity.onCreate`**: `if (savedInstanceState == null) deepLinkRouter.dispatch(intent)`.
4. **`DeviceTokenRegistrar`**: `data class Revocation(userId, token)`, `suspend fun captureRevocation(): Revocation?`
   (reads live auth + cached token NOW), `suspend fun revoke(capture: Revocation?)` (DELETE by the captured pair, never live
   auth, then `dao.clear()`); keep `revoke()` as `revoke(captureRevocation())`.
5. **`SignOutCleanup`** (+ ctor deps `DeepLinkRouter`, `@ApplicationContext Context`): a `bestEffort {}` helper that
   rethrows `CancellationException`; **phase 1 (local, before any network)**: draft fence, `captureRevocation()`, router
   `clear()`, `NotificationManagerCompat.cancelAll()`, outbox/scheduler/stash/prefs/block-cache/pending-payment
   stores/realtime teardown; **phase 2**: `revoke(capture)`. Callers stay source-compatible (no-arg). Update the tests that
   build `SignOutCleanup(...)` or mock `revoke()`: `core/auth/SignOutDraftFenceTest`,
   `features/hospital/RequestServiceAccountSwitchIntegrationTest`, `features/auth/SessionViewModelIdentityTest` (mock
   `captureRevocation()` + `revoke(any())`).
6. **New tests**: `DeepLinkRouterOwnerGateTest` (pure: signed-out drop, Unknown→SignedIn(A) delivers in order,
   A→SignedOut clears, recipient mismatch drops, denied EXTRA_ROUTE never enqueues), `DeepLinkHostOwnerGateTest` (reuse the
   `DeepLinkHostEngineerStatusTest` fixture shape: FakeAuthRepository + RecordingUserPrefs + mockk EngineerRepository),
   `SignOutCleanupOwnershipTest` (revoke receives the capture taken at start even when auth flips to B mid-cleanup; all
   local wipes complete before the network step; cancellation propagates).
7. Then the seven audit scopes → fix list → implement per area with tests → full bar
   (`:app:testDebugUnitTest :app:lintDebug :app:assembleDebug`) → one commit per milestone → this doc.

## Coordination facts (Codex "Astra" build) measured 2026-09-12 02:30–03:00 UTC
- Codex integration branch `codex/auth-integration-20260911` exists ONLY locally in
  `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911` (7 unpushed commits incl. merges
  of both helpers at `8749ff71`, uncommitted edits to `RoleSelectScreenUiTest.kt` + `DeepLinkHostEngineerStatusTest.kt`,
  uncommitted `docs/AUTH_INTEGRATION_2026-09-11.md` + critic/QA drafts). Last activity 2026-09-11 09:17 UTC. Not touched.
- Its frozen slice: A2 dark-contrast fix (RoleSelect button) + A10 review; its critic/QA list two A10 must-fixes
  (observer-lag publication; foreign `Engineer.userId` row accepted). Open program gates: A3, A4/A12, A7, unobserved
  same-ID boundaries, device/TalkBack/locales, signing.
- CI green: `codex/security-foundation-20260907@1e770076`, `codex/helper-engineer-status-20260911@a9b35f3c`, `main@fe463756`.
- Prod: migrations `round3821` (evidence authz), `round3822` (storage-snapshot 30 s timeout), `round3823` are NOT applied.
  **cron-tick-daily has failed 5 days running (09-07…09-11), slot `db-storage-snapshot` only, SQLSTATE 57014** — r3822 is
  the candidate fix; applying it is the founder's call.
- Gradle slot file `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-build-slot.md`: released to FREE by this
  pause.

## Resume checklist
1. `git fetch`; the worktree above is on this branch; copy the two ignored config files again if the worktree was recreated.
2. Re-launch the seven audits (read-only) and collect findings; merge with the table above.
3. Implement fixes 1–6, run the full bar, commit per milestone, push `claudedev-quality-20260912` only.
4. Report base/head SHA, tests run, remaining risks; hand merge order to the coordinator (A10 first, then A3 owner gate —
   both touch `DeepLinkHost.kt`).
