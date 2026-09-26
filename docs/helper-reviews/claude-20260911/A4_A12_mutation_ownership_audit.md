# A4 / A12 — Mutation ownership audit (review only, no code changed)

Reviewer: Claude helper, branch `claudedev-next-review-20260911`, base
`1e770076358e74f6f40a99a4907f831da59e791c`. Scope as assigned: `SignUpViewModel`,
`ProfileViewModel`, every `UserPrefs` writer, `SignOutCleanup`, auth sign-out and token
revocation (`SupabaseAuthRepository.signOut`, `DeviceTokenRegistrar.revoke/register`), plus
the A1/A2 `SessionViewModel` as the reference owner. A8 (profile-read fallback) is a separate
section at the end. Line numbers refer to the file hashes in §8. No test was executed by this
review; "reproduction" rows describe deterministic JVM tests to write.

## 0. What A1/A2 changed, and what they did not

Changed by A1 (`4a2677ea..64107db7`) or A2 (`64107db7..1e770076`) in production code:
`SessionViewModel.kt` (rewritten: login generations, request revisions, mutex-guarded mirror
writes, owned sign-out from gates), `RoleSelectViewModel.kt` (no preference writes, `add_role`
only, generation-fenced), `SupabaseProfileRepository.kt` (`invalidations.invalidate()` after
`updateRole`/`addRole`/`setActiveRole`), `ProfileInvalidations.kt` (new), `RootSessionHost.kt`
(new), `AppNavGraph.kt`, `AuthNavGraph.kt`, `MainNavGraph.kt` (`validatedRole`, no tabs for
unknown roles, `onSwitchService = onProfileSaved`), `HomeHubScreen.kt` (`validatedRole ?:
state.role`), `SignUpScreen.kt` (effects → `onProfileSaved`), `HospitalHomeActions.kt`, strings.

**Not changed** by A1/A2 (every finding below against these files is a pre-existing defect):
`SignUpViewModel.kt` (last change `006b2156`, 2026-06-13), `ProfileViewModel.kt`,
`SignOutCleanup.kt`, `UserPrefs.kt`, `SecurePrefs.kt`, `SupabaseAuthRepository.kt`,
`DeviceTokenRegistrar.kt`, `HomeHubViewModel.kt`, `KycViewModel.kt`,
`RepairJobDetailViewModel.kt`, `RequestServiceDraftStore.kt`.

What the A1/A2 owner already guarantees (so it is not re-reported): role/onboarding mirrors
are written only under `preferenceWrites` with `mayPublish` re-checks between phases
(`SessionViewModel` L425-436); the sign-out mirror clear is fenced by `isCurrentSignOut`
(L163-178); gate sign-out re-checks `isLiveLogin` before cleanup and before `signOut`
(L287-291); the deleted-account path re-checks before each side effect (L391-415); routing
never reads the device mirror (L433-435). A2's own limits, quoted from its comments: "Other
hosts still read these mirrors directly" (L440), "Already-started SignOutCleanup swallows
cancellation and globally wipes stores" (L403-405), "Opaque writers remain A4 work" (L35).

Fences that must be preserved by any change proposed here: `RequestServiceDraftStore
.fenceAndClearForSignOut` (L246-259: synchronous identity/generation fence before the disk
edit, first step of cleanup at `SignOutCleanup` L56, pinned by `SignOutDraftFenceTest`), and
the outbox/scheduler/stash clears that follow it (L58-60) as *immediate* local steps.

## 1. Writer and reader inventory for device-global state

| State (UserPrefs) | Writer | Owner check | Notes |
| --- | --- | --- | --- |
| `activeRole` (SecurePrefs + legacy DataStore key, L68-90) | `SessionViewModel` L428-429 | login + revision + mutex | reference owner |
| | `SessionViewModel` L167 (clear on sign-out) | sign-out generation | |
| | `SignOutCleanup` L62 | none (`runCatching`) | called by three sign-out paths |
| | `SignUpViewModel` L136 | none; `runCatching` swallows cancellation | after `addRole` success |
| | `ProfileViewModel` L221, L295 | none | after `set_active_role` RPC success |
| `v2OnboardingComplete` (L128-136) | `SessionViewModel` L170, L431; `SignOutCleanup` L66 | owned / owned / none | |
| `lastScreen` (L97-105) | `KycViewModel` L76, L80 (no production callers, see A4-08), L96 (`GlobalScope`, `onCleared`); `DeepLinkHost` L89; `SignOutCleanup` L61 | none | consumed by `MainNavGraph` L196-215 |
| `mutedPushCategories`, quiet hours | `NotificationSettingsViewModel` L61-70; `SignOutCleanup` L71-72 | none | user settings |
| `hospitalPostedFirstJob` (L206-210) | `HomeHubViewModel` L310 | none | never reset on sign-out |
| `tourSeen` | `TourScreen` L91 | none | device-level, never reset (acceptable) |
| `themeMode` | settings | n/a | device-level |

Readers that still trust the unowned `activeRole` mirror after A2: `HomeHubViewModel`
L193-200 (re-refreshes on mirror change) and L241-254 (`prefsRole ?: profile.activeRole ?:
profile.role`, mirror **preferred over the server**); `RepairJobDetailViewModel` L1121 →
`resolveViewerRole` L1254-1268 (`selfActiveRole == "engineer"` is the third signal that grants
the engineer viewer role); `EngineerPublicProfileScreen` L221/L260, `AmcDetailScreen` L159,
`MaintenanceContractsScreen` L135 (reported by the exploration pass; not re-read line by line
here). `MainNavGraph` no longer reads it (A2 diff removed both `deepLinkHost.activeRole`
reads). `DeepLinkHost.activeRole` (L43) has no remaining consumer found.

## 2. Findings

### A4-01 · HIGH · `SignOutCleanup.wipeLocalUserState` is global and cancellation-blind (A12)

- Evidence: `SignOutCleanup` L55-95. Every step is `runCatching { … }`, which swallows
  `CancellationException`, so a cancelled caller cannot stop the sequence once started. The
  second step `deviceTokenRegistrar.revoke()` (L57) performs a network DELETE and can suspend
  for the full HTTP timeout. Steps after it are global: `outboxDao.clearAll()` L58,
  `outboxScheduler.cancelAll()` L59, `photoUploadStash.clearAll()` L60, `setLastScreen(null)`
  L61, `clearActiveRole()` L62, `setV2OnboardingComplete(false)` L66, notification settings
  L71-72, `userBlockRepository.clearCache()` L76, the three pending-payment stores L80-82,
  realtime channel removal L90-95. `SessionViewModel` L403-405 admits this boundary.
- Race: A signs out (or A's account is found deleted) → cleanup starts → `revoke()` stalls →
  B signs in and B's owned bootstrap publishes B's gate → the stalled cleanup resumes and
  deletes B's queued outbox rows (bids, status changes, photo uploads, `evidence_register`
  entries), cancels B's scheduler, clears B's photo stash and Razorpay pending-payment markers
  (a paid-but-unverified escrow order then has nothing left for `PendingEscrowPaymentsReconciler`
  to recover), resets B's notification settings and drops B's realtime channels. B's role
  mirror is later corrected by B's owned bootstrap only if the clear lands first.
- Reproduction (JVM, deterministic): build `SignOutCleanup` with a `DeviceTokenRegistrar`
  fake whose `revoke()` awaits a `CompletableDeferred`; start `wipeLocalUserState()` for A;
  switch `FakeAuthRepository` to `SignedIn(B)` and insert an outbox row and a pending escrow
  marker for B; complete the deferred; assert the row and marker survive (target) / are gone
  (today). A same-user variant (A → SignedOut → A, same uid) must also keep A's *new* rows:
  the check has to be on a login token, not on the user id.
- Fix: `wipeLocalUserState(owner: LoginOwner)` in two phases. Phase 1 (synchronous or
  bounded, before any network): the existing draft fence, retire outbox rows *by owner*
  (rows carry the enqueuing actor; verify before relying on it), cancel the scheduler, clear
  the stash, mark the pending-payment markers as belonging to `owner`. Phase 2 (network
  revoke, mirror clears, realtime teardown): every step re-checks `owner.isCurrent()` and stops
  when a new login is observed; the mirror clears move into the owned `SessionViewModel`
  path, which already does them (L163-178). Replace `runCatching` with a helper that rethrows
  `CancellationException`.
- Owner: coordinator (A12). Tests: T-A4-01a/b/c in §4.

### A4-02 · HIGH · `DeviceTokenRegistrar.revoke()` targets whoever is signed in at call time (A12)

- Evidence: `DeviceTokenRegistrar.revoke()` L89-104 reads `supabase.auth.currentUserOrNull()?.id`
  when it runs, not when sign-out started, then deletes `device_tokens WHERE user_id = <that>
  AND token = <cached>` and clears the local DAO. `register()` L55-78 also reads the live user
  and re-checks it before the upsert (good), but the two are not ordered against each other.
- Race: A's late revoke runs after B's `startTokenRegistration` (`SessionViewModel` L328-341)
  has upserted B's row for the same FCM token → the DELETE removes **B's** row → B receives no
  pushes until the token rotates or B signs in again. The reverse order (revoke first, then B's
  register) is correct by accident.
- Reproduction (JVM): `mockkStatic("io.github.jan.supabase.auth.AuthKt")`, a
  `SupabaseClient` mock whose `auth.currentUserOrNull()` returns B during `revoke()`, a DAO fake
  holding token T; assert the delete filter (`user_id = B`) — today B; target: the user captured
  at sign-out start, or no DELETE when the captured user is no longer current.
- Fix: capture `(userId, token)` at sign-out start inside the owned path and call
  `revoke(ownerUserId, token)`; never read live auth inside cleanup. Order in the owned
  sign-out: revoke (needs A's session) → local fences → `signOut` → deferred global wipe.
- Owner: coordinator (A12; unassigned to the GPT helper, whose A10 scope is `DeepLinkHost`).
  Tests: T-A4-02.

### A4-03 · MED · Two sign-out implementations with different guarantees; wipe precedes sign-out

- Evidence: `ProfileViewModel.onSignOut` L592-608 (`runCatching { wipe }` then
  `authRepository.signOut()`; on failure resets `signingOut` and shows `toUserMessage()`),
  `onDeleteAccount` L559-571 (same order), versus `SessionViewModel.signOutFromGate` L276-306
  (owned, `isLiveLogin` between steps, "Couldn't sign out. Please try again." L302).
  `SupabaseAuthRepository.signOut` L210-232 tries GLOBAL, falls back to LOCAL, rethrows the
  original error. If both scopes throw, the device keeps a live session over wiped local state
  and the A2 root keeps MAIN mounted for that user. Neither Profile path carries a login token,
  so a late completion can act after an observed re-login.
- Reproduction (JVM): `FakeAuthRepository` with `signOut()` returning failure; call
  `onSignOut()`; assert wipe ran and the session is still `SignedIn` (today). Same for the
  delete-account path.
- Fix: one owned sign-out entry point (extend `signOutFromGate` into a `SessionViewModel
  .signOut(owner)` usable from Profile), ordering: token revoke → immediate local fences →
  `signOut` → full wipe once `SignedOut` is observed (or at the next login boundary); on
  failure keep the local fences (drafts already fenced) but do not destroy retained work.
- Owner: coordinator (A12). Tests: T-A4-03.

### A4-04 · MED · `SignUpViewModel` role write is unowned and failure-blind (A4/A7)

- Evidence: L108-181. After `AutoSignedIn`: `addRole` (L129); on success `runCatching {
  userPrefs.setActiveRole(role.storageKey) }` (L136) swallows cancellation; on failure only
  `crashReporter.report(it, "signup addRole")` (L139), then the form clears, analytics fires
  (L142-145) and a navigation effect is emitted regardless (L151-156). The repository wraps
  the RPC in `runCatching`, so a cancelled RPC surfaces as `Result.failure(CancellationException)`
  and is *reported as a crash*, unlike `SessionViewModel` L380 / `RoleSelectViewModel` L152
  which rethrow it.
- Under A2 the auth entry is retired as soon as `SignedIn` arrives, which cancels this VM
  mid-RPC (accepted A2 fallback: the chooser asks again). Residual defects: a late successful
  `addRole` still writes the mirror for whichever account is now current (impact limited to
  the readers in §1, chiefly `HomeHubViewModel`), and a failed `addRole` is invisible to the
  user until the chooser appears.
- Fix (A7 scope per the A2 handoff): hand the chosen role to the root as an owned intent
  (`SessionViewModel.recordSignupRoleChoice(owner, role)`) instead of writing the mirror; the
  root applies it via `add_role` under its own generation; treat cancellation as cancellation;
  on failure show retry copy instead of navigating.
- Owner: coordinator (A7/A4). Tests: T-A4-04.

### A4-05 · MED · `ProfileViewModel` role editor writes the mirror without identity (A4)

- Evidence: `onRoleEditorConfirm` L190-255 and `onToggleRoleAndGoHome` L277-305: `addRole` →
  `setActiveRole` RPC → `userPrefs.setActiveRole(target)` (L221, L295) → optimistic local
  `profile.copy(...)` (L224-231) → `Effect.NavigateHome`. Identity comes from
  `current.profile?.id` captured at tap time (L193); there is no re-check of the live session
  before the mirror write. Since A2 the repository's `invalidate()` already triggers the owned
  root refresh, so the mirror write and the optimistic copy are redundant for routing and only
  feed the unowned readers (§1).
- Race: late success after A → B (or A → SignedOut → A) writes A's chosen role into the
  device mirror under B; `HomeHubViewModel` L193-200 then refreshes B's hub as A's role.
- Fix: drop the mirror write and the optimistic copy; rely on `invalidate()` → owned refresh
  → `SessionPresentation`; keep the RPC order (`add_role` before `set_active_role`, which the
  Codex route inventory asked to preserve).
- Owner: coordinator (A4). Tests: T-A4-05.

### A4-06 · MED · `HomeHubViewModel` still derives data role from the mirror (A4, partly mitigated by A2)

- Evidence: L241-254 (`prefsRole ?: profile.activeRole ?: profile.role`, comment "Prefer
  userPrefs over server fields"), L193-200 (refresh on mirror change), L157-178 (session
  discriminator `in:uid`). A2 changed only the rendered role (`HomeHubScreen` `validatedRole ?:
  state.role`), so the *data* the hub loads (tile RPC set, KYC banner fetch, `isFounder`) still
  follows the mirror and can disagree with the tabs after any stale write in A4-04/A4-05 or a
  failed sign-out clear.
- Fix: pass the validated role (or collect `SessionViewModel.presentation`) into the VM and
  delete the mirror read; the mirror remains write-through for legacy consumers only.
- Owner: coordinator (A4, "HomeHub data loading" is already listed). Tests: T-A4-06.

### A4-07 · MED · `RepairJobDetailViewModel` grants the engineer viewer role from the mirror

- Evidence: L1121 `val selfActiveRole = userPrefs.activeRole.firstOrNull()`; L1254-1268
  `resolveViewerRole(...)`: `selfActiveRole == "engineer" -> ViewerRole.Engineer` after the
  engineers-row and profile-role signals. The hospital role is derived from `selfId ==
  job.hospitalUserId` (server data). Writes are still blocked by the phone/KYC gates (L459-480)
  and by RLS, so this is a UI-affordance defect, not an authorization bypass.
- Fix: derive the viewer role from the validated session role plus server rows only.
- Owner: coordinator (A4). Tests: T-A4-07.

### A4-08 · LOW · `lastScreen` pin: dead entry points plus an unfenced `GlobalScope` clear

- Evidence: `KycViewModel.markEntered()` L75-77 and `markExited()` L79-81 have **no
  production callers** (grep), so the pin is never set; `onCleared` L92-96 still fires
  `GlobalScope.launch { setLastScreen(null) }`, an unowned write that can land after a later
  login set its own pin. `MainNavGraph` L196-215 and `DeepLinkHost.consumeLastScreen` L87-90
  therefore run against a value only the sign-out clear ever writes. `SignOutCleanup` L61
  clears it best-effort.
- Fix: either remove the pin machinery or, when re-enabled, store `owner:route`, write and
  clear it through the owned root writer, and ignore foreign owners on restore (see A3-05).
- Owner: coordinator. Tests: T-A4-08.

### A4-09 · LOW · Two-phase mirror setter and legacy-key fallback

- Evidence: `UserPrefs.setActiveRole` L82-85 writes SecurePrefs synchronously (observers see
  it at once through `SecurePrefs.stringFlow`'s change listener, `SecurePrefs.kt` L69-75), then
  suspends on `prefsStore.edit { remove(legacy) }`; `clearActiveRole` L87-90 mirrors that.
  `activeRole` is `combine(secure, legacy) { secure ?: legacy }` L68-71, so on a device that
  still has the legacy key, `clearActiveRole` exposes the legacy value between the two phases,
  and a cancellation between them leaves the keys inconsistent. A1 already isolates routing
  from this (comment L433-434); readers in §1 are still exposed.
- Fix: one-time migration that removes the legacy key, then drop the `combine`; or clear the
  legacy key first.
- Owner: coordinator (A4). Tests: T-A4-09 (Robolectric with a seeded legacy key).

### A4-10 · LOW · Cross-account leftovers not covered by cleanup

- Evidence: `hospitalPostedFirstJob` (`UserPrefs` L206-210, written `HomeHubViewModel` L310)
  is never reset by `SignOutCleanup`; the next account inherits the "already posted" hub state.
  The Room v5 `RepairPhotoDelivery*` tables have owner/session/generation fences
  (`RepairPhotoDeliveryDao.activate/deactivate` L426-457) but no production caller yet (only
  `AppDatabase` references them) and `SignOutCleanup` does not touch them; when wired, the
  fence must be driven by the login owner, not by the global cleanup.
- Fix: add the flag to the owned cleanup or key it by user; document the Room v5 activation
  contract for the login owner.
- Owner: coordinator. Tests: T-A4-10.

### A4-11 · LOW · Owned gate sign-out inherits wipe-before-signOut and hardcoded copy (A2-introduced surface)

- Evidence: `SessionViewModel.signOutFromGate` L286-303: `wipeLocalUserState()` runs before
  `authRepository.signOut()`; on non-cancellation failure the user is left on the recovery
  screen with a live session and wiped local state, message `"Couldn't sign out. Please try
  again."` (hardcoded English, L302). Not a regression (no gate sign-out existed before) but
  the same shape as A4-03.
- Fix: same ordering change as A4-03; string resource. Owner: coordinator (A2 follow-up).

### Boundary that no local change closes (recorded, not a finding)

A same-user re-login that the `StateFlow` conflates (no `SignedOut`/`B` observed) is
indistinguishable from a token refresh at every layer above `AuthRepository` (A1's own
statement, `SessionViewModel` L52-54). The only fix is repository-issued identity: expose a
`SessionIdentity(userId, sessionId, loginSeq)` from `SupabaseAuthRepository` derived from
`SessionStatus.Authenticated.session` (the access token already carries a `session_id` claim,
which `TestSupabaseClient` decodes), and let generations be issued from it. All owner tokens
proposed below should be built on that identity once it exists.

## 3. Owned write boundaries (proposal, coordinator-owned)

1. **One `LoginOwner` token** (`userId`, `generation`, later `sessionId`) issued by the root
   session owner; every mutation that touches device-global state carries it. Comparing user
   ids alone is not enough (A → SignedOut → A), and cancellation alone is not enough (started
   work that swallows cancellation, network calls already in flight).
2. **`OwnedDeviceState` writer**: a single, mutex-serialised writer for `activeRole`,
   `v2OnboardingComplete`, `lastScreen`, `hospitalPostedFirstJob`; writes carry the owner and
   are dropped when the owner is not current at write time *and* re-checked after the
   suspending write (both phases). `SessionViewModel` already implements this pattern for two
   keys; extend rather than duplicate.
3. **Readers stop trusting the mirror**: `HomeHubViewModel`, `RepairJobDetailViewModel`,
   `EngineerPublicProfileScreen`, `AmcDetailScreen`, `MaintenanceContractsScreen` take the
   validated role from `SessionPresentation`.
4. **Sign-out is one owned sequence**: revoke(captured ids) → immediate local fences (draft
   fence first, then outbox/scheduler/stash by owner) → `signOut` → deferred global wipe only
   while the owner is current; cleanup helpers rethrow cancellation.
5. **Stores expose `retire(owner)`** where rows are per-user (outbox entries, pending payment
   markers, photo stash), keeping `clearAll()` for the deferred global phase.

## 4. Deterministic tests (fakes and barriers; none written here)

Fixtures available today: `FakeAuthRepository.setSession`, `FakeProfileRepository` knobs,
`RecordingUserPrefs` (ordered writes, before-write and after-publication pauses as extended by
Codex), MockK for the final classes (`DeviceTokenRegistrar`, `SignOutCleanup`, `CrashReporter`,
`AnalyticsClient` are already mocked elsewhere). Barriers: `CompletableDeferred` awaited inside
a fake's suspend call.

| ID | Class (new) | Stimulus | Today | Target |
| --- | --- | --- | --- | --- |
| T-A4-01a | `core/auth/SignOutCleanupOwnershipTest` | wipe(A) parked in `revoke()`; `SignedIn(B)`; B enqueues outbox row + escrow marker; release | B's row/marker deleted | retained |
| T-A4-01b | same | wipe(A) parked; `SignedOut`; `SignedIn(A)` new generation; A enqueues; release | deleted | retained (owner token, not uid) |
| T-A4-01c | same | cancel the caller while parked | remaining steps still run | sequence stops after the current step |
| T-A4-02 | `core/push/DeviceTokenRegistrarRevokeIdentityTest` | live auth = B during A's `revoke()` | DELETE `user_id = B` | DELETE for captured A or no-op |
| T-A4-03 | `features/profile/ProfileSignOutOrderingTest` | `signOut()` fails (GLOBAL and LOCAL) | wiped + still signed in | fences applied, retained work kept, session state honest |
| T-A4-04 | `features/auth/SignUpRoleOwnershipTest` | `addRole` parked; `SignedOut`; `SignedIn(B)`; release success | mirror write lands, navigation emitted, analytics fired | no mirror write; no effect for B; cancellation not reported as a crash |
| T-A4-05 | `features/profile/RoleEditorOwnershipTest` | `setActiveRole` RPC parked; account switch; release | mirror written for B | no write; root refresh only |
| T-A4-06 | `features/home/HomeHubRoleSourceTest` | mirror says engineer, validated role hospital | engineer data loaded | hospital data; mirror ignored |
| T-A4-07 | `features/repair/ResolveViewerRoleTest` (pure) | mirror "engineer", no engineers row, hospital profile | `ViewerRole.Engineer` | not engineer |
| T-A4-08 | `features/kyc/LastScreenOwnershipTest` | A's `onCleared` clear parked; B sets pin; release | B's pin cleared | kept |
| T-A4-09 | `core/data/prefs/UserPrefsLegacyRoleKeyTest` (Robolectric) | seed legacy key, `clearActiveRole` with the DataStore edit parked | legacy value observed | null |
| T-A4-10 | `core/auth/SignOutCleanupCoverageTest` | wipe; read `hospitalPostedFirstJob` | true survives | reset |

Every "account switch" row must be run in both shapes: A → B, and A → SignedOut → A with the
same uid. A test that passes only because the uid differs has not proven ownership.

## 5. A8 — profile-read fallback ambiguity (separate recommendation; `SupabaseProfileRepository` not edited)

Evidence: `SupabaseProfileRepository.fetchById` L23-80. Both self selects are wrapped in
`runCatching { … }.getOrNull()` (L29-41), so transport errors, RLS denials and decode
failures are indistinguishable from "no row". Control then falls to the cross-user RPC
`public_profiles_minimal` (L61) and, if it returns a row, **synthesises** a `Profile` with
`role = null`, `roleConfirmed = false`, `isActive = true`, `phone = null` (L62-78); if it
returns nothing, `success(null)`. The payout RPC failure folds to `null` (L50-53), which
`Profile.hasCompletedV2Onboarding` treats as complete.

Consequences under A1/A2 (`SessionViewModel` L385-424, `rootDestination`):

| Repository outcome | Root behaviour | Problem |
| --- | --- | --- |
| Self selects fail transiently, RPC returns the row | synthetic profile → `NeedsRole` → chooser → `add_role` (idempotent) → `invalidate` → refetch; if the selects still fail, chooser again | an onboarded user loops on role confirmation; each loop calls `add_role` |
| Self selects fail, RPC empty (row really gone, or RPC filtered) | `success(null)` → deleted-account wipe + sign-out + "Your account is no longer active" | destructive action taken on an ambiguous read |
| Self selects fail, RPC throws (offline) | `Result.failure` → `profileFailed`, gate retained | correct today |
| Row for another id | A2 rejects (`fetched.id != login.userId`, L386) | correct |
| Payout RPC fails | `hasEngineerPayoutComplete = null` → onboarded | engineer skips the payout gate on a transient error (Codex inventory gap 5) |

Recommendation (test-first, coordinator-owned):

1. Return a typed outcome from the self lookup: `Found(profile)`, `NotFound` (only for an
   authenticated 200 with an empty result on the self select), `Unavailable(cause)` (transport,
   RLS, decode, timeout). Never synthesise a profile for the *self* lookup; move the minimal
   RPC into a separate `fetchPublicById` for chat peers and directory callers.
2. `SessionViewModel`: `Unavailable` → `profileFailed` (retry UI, gate retained); `NotFound`
   → the existing deleted-account path; only `Found` publishes a gate.
3. Payout readiness: expose `Unknown` distinctly from `Complete`; the onboarding host shows
   a checking/retry state instead of admitting MAIN (product rule "preserve the existing payout
   prerequisite" from the plan).
4. Tests with `TestSupabaseClient` (MockEngine): self select 200 empty + RPC row (today
   synthetic, target `NotFound` vs `Unavailable` decided by the select status); 401/403 on the
   self select (target `Unavailable`); malformed JSON (target `Unavailable`); payout RPC 500
   (target `Unknown`); plus a `SessionViewModelIdentityTest` case that `Unavailable` never
   triggers cleanup or the chooser.

## 6. Not verified

- No test was executed; the race rows are constructed from the code paths cited, not observed.
- Outbox rows: whether they carry the enqueuing actor id (needed for owner-scoped retire) was
  not confirmed in this pass.
- The mirror readers reported for `EngineerPublicProfileScreen`, `AmcDetailScreen`,
  `MaintenanceContractsScreen` come from the exploration pass and were not re-read here.
- Server-side behaviour of `add_role` when repeated (assumed idempotent from the migration
  text read in the previous audit).

## 7. Ownership summary

| Finding | Owner | Slice |
| --- | --- | --- |
| A4-01, A4-02, A4-03, A4-11 | coordinator | A12 (sign-out and cleanup internals) |
| A4-04 | coordinator | A7 (signup carryover) |
| A4-05, A4-06, A4-07, A4-09, A4-10 | coordinator | A4 (opaque writers and HomeHub data) |
| A4-08 | coordinator | A3/A4 overlap (lastScreen) |
| A8 | coordinator | A8 |

## 8. Reviewed files (SHA-256, git blob, lines)

```text
73ff26f00474fee4f21593fdb214de2d4e13148dabf2bc652f0694ea045d7dd9  9f2e5d73  265   features/auth/SignUpViewModel.kt
6b5a33e1e5ee1fefd26602e754095246166a30cf4a9b121c2f97968fabc31de2  0e3f54ec  723   features/profile/ProfileViewModel.kt (L118-172, L172-305, L540-608, L610-640 read)
891a92974b08876997c158384359c1aed69d61ea3275e7046519ba139ab0800e  93cb4b56  97    core/auth/SignOutCleanup.kt
9d761f5664e9dcc1496a26c3c702360e04cdd4fe5cd358cb9f7b19a1697b4ab8  bb76d4c2  230   core/data/prefs/UserPrefs.kt (L55-140, signatures)
e231dc884043da6a25ddfd8fdb20f37766a9a804ad7bed5767f3d601b0bc97c4  a83f3b1c  92    core/data/prefs/SecurePrefs.kt (signatures)
363453d3f88e130251eac494350d342ac931956eef8f5cbde2f06a31f2499eaf  25a8effa  267   core/auth/SupabaseAuthRepository.kt (L1-120, L198-237)
eeecdb31902bb7c7aab11630057a216f93d406dcf7c6d8862fdb395d744175e6  7a441a12  105   core/push/DeviceTokenRegistrar.kt
31565f5f9442f448d8b39cfb45c2d2e7947782d9484d8f0efc14e48d2db88646  62cf061d  236   core/data/profile/SupabaseProfileRepository.kt (L18-98 + A2 diff)
92faeae469e440f6e5f11e4779e33cfb2ccb9d3c843b50227895d46a2fb89e00  846edba1  462   features/auth/SessionViewModel.kt
ac99bf477625af0c022bc1250e58504e8657e1606d86c8152f736b82e941efc1  d594c5f7  221   features/auth/RoleSelectViewModel.kt
cf19b738305e81ff3085dd3a1048fa1eebf364d82dc6fc22f41993ab8030047f  cec9c423  477   features/home/HomeHubViewModel.kt (L150-200, L236-262)
1c47570822bdfa7fc9a25bb9520a616d5ff1b54356350e3373f1ea7761ba2fd2  e75f9041  1100  features/kyc/KycViewModel.kt (L66-100)
ccd3d4c9c40d86355ff9923fca6eaca611d820e7df052079c1a3d3fa2ef432e5  8122afe1  292   core/data/repair/RequestServiceDraftStore.kt (L246-274)
865e5db464dcb1d5c3e4ce169205ad54642c20af785d897aedb1dcaa8a9b5d7e  f06bd498  701   features/onboarding/EngineerPayoutOnboardingScreen.kt (L364-382)
```
