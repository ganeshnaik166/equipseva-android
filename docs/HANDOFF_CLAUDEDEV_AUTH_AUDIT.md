# Handoff — `claudedev-auth-audit` (UI-A01 auth / navigation audit)

**Status: PARTIAL, STOPPED BY OWNER (usage limit) on 2026-09-10.** Read the
"What is and is not done" section before trusting anything else here.

That status describes the helper branch at `fc5ece04`. Codex integration corrections
and their bounded fixture validation are recorded in §8; they do not implement F1–F20.

| Item | Value |
| --- | --- |
| Branch | `claudedev-auth-audit` (cut from `origin/codex/security-foundation-20260907`) |
| Base HEAD (verified before any work) | `4a2677ea057017aaa9a61827e0a236e1bca08a8a` |
| Scope instruction | Owner message "Work only on UI-A01 …" (2026-09-10). `UI-A01` is not defined anywhere in the repo docs (`grep -rn "UI-A01" docs/` is empty); the owner's message is treated as the scope definition. |
| Plan of record | `docs/RENEWAL_EXECUTION_PLAN.md` (M2a route/action matrix, M4 login/recovery/role/onboarding, product rule "an unknown role must not silently acquire another role's interface or access") |
| Previous helper handoff | `docs/HANDOFF_CLAUDEDEV_HELP.md` (merged into the Codex branch at `1054e473`) |
| Production behaviour changed | **None.** Only files under `app/src/test/` and this document were added. |
| Reviewer scores | **Not claimed.** No critic / QA review ran; required evidence (test run log, hashes) does not exist yet. |
| Merge target | Do **not** merge to `main` or to the Codex branch. Codex decides. |

Files that must never be touched by this branch (owner constraint): `HomeHubScreen.kt`,
`HospitalHomeActions.kt`, `MainNavGraph.kt`, Room / photo-persistence files, Gradle files.
Also untouched by rule: Supabase data, payments, jobs, bids, evidence, migrations, secrets,
deployment, CI workflow files.

---

## 0. What was and was not done on the helper branch

Done (committed on this branch):

1. Complete source reading of the auth / navigation surface (list in §1).
2. Route / state inventory (§2) and security findings F1–F20 with evidence (§3).
3. Test-first plan with provisional implementation recipes (§4).
4. Two **test fixtures** (no tests yet):
   - `app/src/test/kotlin/com/equipseva/app/testing/RecordingUserPrefs.kt` — MockK-backed
     `UserPrefs` double with driveable flows, ordered write recording, and a
     before-write and after-publication suspension hooks. The integration correction adds
     a unified typed `writeEvents` ledger for cross-method order, and normalises blank
     last-screen values to null while retaining raw arguments in the ledger.
   - `app/src/test/kotlin/com/equipseva/app/testing/AuthAuditFixtures.kt` — `Profile`
     fixtures for the three server states the gate distinguishes (confirmed, trigger-default
     unconfirmed engineer, minimal-RPC fallback).

**Not done — do not assume otherwise:**

- The fixtures have **not been compiled or run**. `./gradlew :app:testDebugUnitTest` was not
  executed on this branch. Treat them as drafts until a green run is recorded here.
- No test classes from §4 exist yet (SessionViewModel, RoleSelect, SignIn, SignUp,
  DeepLinkRouter/Host, session mapping).
- No critic / QA review, therefore no score.
- No CI run was recorded for the helper commit. `android.yml`, `secret-scan.yml`, and
  `evidence-regressions.yml` use push branches
  `[main, "ops/**", "codex/**", "claudedev-help"]`, excluding `claudedev-auth-audit`.
  This is not a filter shared by every workflow: web and assetlinks have narrower
  branch/path filters, release uses tags, and operational workflows use schedules/manual
  dispatch. A PR can trigger eligible PR workflows subject to their own filters;
  branch presence alone does not establish a run or a passing result.

Resume point: §5 "Resume checklist".

---

## 1. Sources read (evidence base)

`features/auth/SessionViewModel.kt`, `navigation/AppNavGraph.kt`, `navigation/AuthNavGraph.kt`,
`MainActivity.kt` + manifest (exported, singleTop), `navigation/DeepLinkRouter.kt`,
`navigation/DeepLinkHost.kt`, `navigation/MainNavGraph.kt` (read-only; deep-link consumer at
~L215-228), `navigation/Routes.kt`, `core/auth/AuthRepository.kt`,
`core/auth/SupabaseAuthRepository.kt`, `core/auth/AuthError.kt`, `core/auth/SignOutCleanup.kt`,
`core/network/DataError.kt` (`toUserMessage`), `core/push/DeviceTokenRegistrar.kt`,
`features/auth/{RoleSelectViewModel,SignInViewModel,SignUpViewModel,ForgotPasswordViewModel}.kt`
and their screens, `features/auth/google/GoogleSignInClient.kt`, `features/auth/state/*`,
`core/data/prefs/UserPrefs.kt`, `core/data/profile/{Profile,SupabaseProfileRepository}.kt`,
`features/home/{HomeHubViewModel,HomeHubScreen}.kt` (read-only), `features/profile/ProfileViewModel.kt`,
`features/onboarding/{HospitalPhoneOnboardingScreen,HospitalOnboardingScreen,EngineerOnboardingScreen,TourScreen}.kt`,
server: `supabase/migrations/20260428090000_security_critical_block_role_escalation.sql`
(`handle_new_user` hardcodes `'engineer'`), `20260426010000_multi_role_schema.sql`
(`_sync_profile_roles`, `add_role`, `set_active_role`), `public_profiles_minimal` RPC.
Existing tests: `RoleSelectStateTest`, `UserRoleEnumTest`, `TabRoutesForRoleTest`,
`DeepLinkRouterTest` (pure `routeForParts` only), `ProfileV2OnboardingGateTest`,
`ForgotPasswordViewModelTest`, `SignOutDraftFenceTest`. **No tests exist for**
`SessionViewModel`, `SignInViewModel`, `SignUpViewModel`, `RoleSelectViewModel`, `DeepLinkHost`,
or the `SessionStatus → AuthSession` mapping. `navigation-testing` (TestNavHostController) is not
on the test classpath.

supabase-kt 3.6.0 shapes verified with `javap` on `auth-kt.aar`:
`SessionStatus.Authenticated(UserSession, SessionSource)`, `NotAuthenticated(isSignOut)`,
`Initializing`, `RefreshFailure(RefreshFailureCause)`; `RefreshFailureCause.NetworkError(Throwable)`,
`.InternalServerError(RestException)`; `Auth.sessionStatus: StateFlow<SessionStatus>`;
`UserInfo(aud, id, email…)`, `SessionSource.External` (already used by `TestSupabaseClient`).

---

## 2. Route / state inventory

### 2.1 Session layers

```
supabase-kt SessionStatus ──map──▶ AuthSession ──combine(prefs.activeRole, bootstrapping,
  Initializing            ▶ Unknown            profileOnboardingV2Complete, prefs.v2OnboardingComplete)──▶ SessionState
  NotAuthenticated(any)   ▶ SignedOut           Unknown                              ▶ Loading
  RefreshFailure(any)     ▶ SignedOut  (F5)     SignedOut                            ▶ SignedOut
  Authenticated(sess)     ▶ SignedIn(user?.id ?: "", user?.email)  (F8)
                                                SignedIn + role blank + bootstrapping ▶ Loading
                                                SignedIn + role blank                 ▶ NeedsRole(userId,email)   (no UI, F2)
                                                SignedIn + role + (fetched ?: cached) ▶ Ready(userId,email,role)
                                                SignedIn + role + not onboarded       ▶ NeedsOnboarding(userId,email,role)
```

`bootstrapProfile(userId)` runs once per **distinct userId** on the SignedIn stream
(`distinctUntilChangedBy { it.userId }`, `SessionViewModel.kt:59`) and again on `refreshNow()`
(ON_RESUME after the first, onboarding "done"). Sign-out collector (`:81-92`): clears the
device-global `activeRole`, resets `bootstrapping`, `profileOnboardingV2Complete=null`,
`profileBaseV2Done=false`.

### 2.2 Root hosts (`AppNavGraph.kt`)

| SessionState | Cold start (`coldStartRoute`, remembered once) | Live transition (LaunchedEffect) |
| --- | --- | --- |
| Loading | Splash | Splash while Loading; no navigation |
| SignedOut | `AUTH_GRAPH` | → `AUTH_GRAPH` only if the app previously saw an authenticated state (`sawAuthenticated`) |
| NeedsRole | falls into `main_host` (the `else` branch) | **no handler** — stays wherever it is |
| NeedsOnboarding | `onboarding_host` | → `onboarding_host` |
| Ready | `main_host` | → `main_host` |

Consequences: `NeedsRole` on cold start mounts **MainNavGraph with `activeRole == null`** →
`tabRoutesForRole(null)` = engineer tabs; `HomeHubScreen` has no null-role branch (F2).

### 2.3 Auth graph (`AuthNavGraph.kt`)

| Route | Success | Cancel / Back | Retry | Offline | Restart (process death) | Stale session |
| --- | --- | --- | --- | --- | --- | --- |
| `Welcome` | → SIGN_IN / SIGN_UP | Back exits app | — | n/a | re-mounts Welcome | n/a |
| `SIGN_IN` (`SignInViewModel`) | `signInWithEmailPassword` ok → `AuthEffect.NavigateToHome`; the effect is *informational* — the real transition is `AuthSession.SignedIn` → root gate | Back → Welcome; Google picker cancel → form reset silently | error copy in `form.errorMessage`, resubmit allowed; double-submit guarded by `submitting` | IOException → "Network problem. Check your connection and retry." | in-flight request lost; form state lost (VM not saved) | effects `SharedFlow(replay=0)`: an effect emitted with no collector is dropped (by design, PR #584) |
| `SIGN_IN` Google | `Token → signInWithGoogleIdToken(idToken, rawNonce)` | `Cancelled → FormUiState()` | `Error(message)` passthrough | as above | as above | `NotConfigured` → "Google sign-in isn't configured for this build." |
| `SIGN_UP` (`SignUpViewModel`) | `AutoSignedIn` → `addRole(role)` → `setActiveRole` (only on addRole success) → analytics → HOSPITAL: `NavigateToHospitalPhoneOnboarding`, else `NavigateToHome` **regardless of addRole result** (F11) | "Sign in" link = `popBackStack(AUTH_SIGN_IN, inclusive=false)` — **no-op when SignUp was reached from Welcome** (F10) | validation banners; "Pick how you'll use EquipSeva" when role missing | IOException → Network copy | form lost | `NeedsEmailConfirmation` → `UiState()` reset + `ShowMessage("Verification link sent to <email>. Open it, then sign in.")`; confirmation completes on the **web** only (F15) |
| `FORGOT_PASSWORD` | `sendPasswordResetEmail(redirect https://equipseva.com/auth/reset)` → `sent=true` | Back | resend allowed | Network copy | — | recovery completes on the web page (`docs/auth/reset.html`); `/auth/reset` deliberately **not** an App Link; app has no "password changed" state (F19) |
| `HOSPITAL_PHONE_ONBOARDING` (after hospital signup / RoleSelect) | onDone `popBackStack(AUTH_GRAPH, inclusive=true)`; `AuthHostInline` hands off only after `sawSignedOut` and not while on this route | `BackHandler(enabled=true){}` **swallows Back** (screen is inescapable) | AddPhoneViewModel retry | Network copy | re-mount depends on root gate: the root gate may already be `NeedsOnboarding` and jump to `onboarding_host` (F6 race) | session read at save time |
| `RoleSelectScreen` | `updateRole(uid, role)` → `setActiveRole` → HOSPITAL: phone onboarding, else Home | — | `error.toUserMessage()` | Network copy | — | **zero call sites** (`grep RoleSelectScreen(` → only the definition) → `NeedsRole` has no UI (F2) |

### 2.4 Onboarding host (`OnboardingHostInline`)

Dispatch by role: engineer → `EngineerOnboardingScreen` (step 1) or payout screen when
`profileBaseV2Done`; other roles → `HospitalOnboardingScreen`. `handleDone = refreshNow(); onDone()`.
No back stack: **Back exits the app** (F16). Offline save → screen-level error; the gate stays
`NeedsOnboarding`. Process death → cold start recomputes from cache: role cached + v2 cache
**false** (not yet promoted) → `NeedsOnboarding` again (correct); if the v2 cache is stale-true
from a previous same-device account whose wipe failed → `Ready` (SignOutCleanup best-effort, F12).

### 2.5 Main host (`MainNavGraph.kt`, read-only)

- Deep links: `DeepLinkHost.events` → `runCatching { navController.navigate(event.route) }`
  (~L215-228). **No allow-list**, no role check, no session check.
- Founder routes (`founder/dashboard`, `founder/kyc`, `founder/users`, `founder/payments`, …)
  are mounted in the main graph; UI entry only via `onOpenFounder` from Profile when
  `Profile.isFounder()` (email compare). Data behind them is protected server-side by
  `is_founder()` — the **UI** is reachable by any signed-in user via `EXTRA_ROUTE` (F4).
- `HOSPITAL_ONBOARDING` / `ENGINEER_ONBOARDING` are also mounted inside main (second entry).
- `lastScreen` restore: `DeepLinkHost.lastScreen` read once; `consumeLastScreen()` clears it;
  `SignOutCleanup` also clears it (best-effort).
- ON_RESUME (not first) → `SessionViewModel.refreshNow()` (zombie / role change catch-up).

### 2.6 Account switching (device-global state)

`UserPrefs.activeRole`, `v2OnboardingComplete`, `lastScreen`, `tourSeen` are **device-global**,
not keyed by user. Writers: `SessionViewModel.bootstrapProfile` (server-confirmed role),
`RoleSelectViewModel.onConfirm`, `SignUpViewModel` (after `addRole`), `ProfileViewModel` role
editor (`addRole` → `setActiveRole` RPC → prefs). Clearers: `SessionViewModel` sign-out
collector, `SignOutCleanup.wipeLocalUserState()`. None of the writers re-checks the **current**
session identity before writing (F9).

Sign-out (`ProfileViewModel.onSignOut`): `wipeLocalUserState()` **then** `authRepository.signOut()`
(GLOBAL, fallback LOCAL, rethrow). If both scopes fail the device keeps a live session with wiped
local state (F12).

### 2.7 Deep links (`MainActivity` exported, `singleTop`)

`onCreate`/`onNewIntent` → `DeepLinkRouter.dispatch(intent)`:
`intent.getStringExtra(EXTRA_ROUTE)?.takeIf { isNotBlank } ?: routeFor(intent.data)` →
`Channel(BUFFERED).trySend(OpenRoute(route))`. The https path whitelist
(`/job/RPR-…`, `/chat/<uuid>`, `/engineer/<uuid>`, `/engineers`, `/notifications`) applies **only**
to URIs; `EXTRA_ROUTE` is forwarded verbatim. The router is a `@Singleton` with no reset API, so
buffered events survive sign-out and are delivered to the next `DeepLinkHost` collector
(F4). Process-death recreation re-delivers the launch intent → re-dispatch.

---

## 3. Security findings

Severity: **HIGH** = violates a plan product rule or grants a UI/access path across identity
boundaries; **MED** = wrong state or destructive local action under realistic conditions;
**LOW** = UX dead-ends and copy.

| # | Sev | Finding | Evidence |
| --- | --- | --- | --- |
| F1 | MED | **Profile-readiness fail-modes.** `fetchById` wraps both self-selects in `runCatching{}.getOrNull()`; a decode/RLS failure falls to the `public_profiles_minimal` RPC. Row present → synthetic profile (`roleConfirmed=false`, `isActive=true`, `phone=null`) → onboarded users bounce to `NeedsOnboarding` (fetched `false` overrides the sticky-true cache). RPC empty → `success(null)` → treated as a **deleted account**: local wipe + sign-out + "Your account is no longer active. Sign in again." Offline is safe only because the RPC throws (→ `failure` → cached role kept). | `SupabaseProfileRepository.fetchById`; `SessionViewModel.kt:197-219, 258-263` |
| F2 | **HIGH** | **`NeedsRole` has no UI; unknown role acquires the engineer interface.** `RoleSelectScreen` has no call sites; `AppNavGraph` has no `NeedsRole` branch (cold start falls to `main_host`); `tabRoutesForRole(null)` = engineer tabs; `HomeHubScreen` branches ENGINEER/HOSPITAL only. Server default (`handle_new_user` → `role='engineer'`, `_sync_profile_roles` → `active_role='engineer'`, `role_confirmed=false`) means every first-time Google sign-in and every email signup whose `add_role` failed reaches the hub as an unconfirmed engineer. Violates the plan rule "an unknown role must not silently acquire another role's interface or access". Only escape: Profile role editor. | `SessionViewModel.kt:157, 248-252`; `AppNavGraph.kt` LaunchedEffect; `TabRoutesForRoleTest`; migrations above |
| F3 | **HIGH** | **Same-account re-login skips bootstrap.** `distinctUntilChangedBy { it.userId }` suppresses the second `SignedIn(A)` after `SignedOut` cleared `activeRole` → state `NeedsRole` (→ engineer tabs per F2), no zombie/inactive check, no role sync until ON_RESUME `refreshNow()`. Plan explicitly requires "the same account logging in again" coverage. | `SessionViewModel.kt:57-79, 81-92` |
| F4 | **HIGH** | **Deep-link route injection + cross-account replay.** `EXTRA_ROUTE` from **any** intent to the exported activity is navigated verbatim (`runCatching { navigate(route) }`), incl. `founder/*` UI, onboarding screens, and any parameterised route. Buffered router channel replays links across sign-out to the next account; process-death recreation re-dispatches the launch intent. | `DeepLinkRouter.kt:38-44`; `DeepLinkHost.kt:108-119`; `MainNavGraph.kt` ~215-228; manifest `exported="true"` |
| F5 | MED | **`RefreshFailure → SignedOut`.** Any refresh failure (incl. `NetworkError`, i.e. offline at token expiry) is indistinguishable from an explicit sign-out: root gate → Welcome, `activeRole` cleared, in-flight screens torn down. No retry/grace state. | `SupabaseAuthRepository.kt:22-36`; `SessionViewModel.kt:81-92` |
| F6 | MED | **Hospital signup destination race.** `AuthHostInline` phone gate vs root `NeedsOnboarding` gate: whichever observes first decides whether the user lands on `HOSPITAL_PHONE_ONBOARDING` (auth graph) or `onboarding_host` (`HospitalOnboardingScreen`). Timing-dependent; not covered by tests. | `AppNavGraph.kt` (`AuthHostInline`, `sawSignedOut`, `HOSPITAL_PHONE_ONBOARDING` guard) |
| F7 | MED | **Transient `NeedsOnboarding` on fresh sign-in of an onboarded account.** After the wipe, `cachedOnboarding=false`; `setActiveRole` (suspends on DataStore) makes the combine emit `NeedsOnboarding` before `profileOnboardingV2Complete` is set → `onboarding_host` mounts then `main_host` replaces it. | `SessionViewModel.kt:250-263` |
| F8 | MED | **`SignedIn(userId="")`.** `Authenticated` with `session.user == null` maps to an empty id; `bootstrapProfile("")` → `fetchById("")` → no row → deleted-account wipe + sign-out with misleading copy; offline → `NeedsRole("")`. | `SupabaseAuthRepository.kt:25-31`; `SessionViewModel.kt:157` |
| F9 | MED | **Stale device-global role writes after account switch.** `RoleSelectViewModel.onConfirm` resolves the session once (`first()`), then `updateRole` (server-guarded by `authUid == userId`) but `setActiveRole` is written with no identity re-check; same pattern in `SignUpViewModel` and `ProfileViewModel`. A late callback after sign-out / another account writes the previous user's role for the new user. | `RoleSelectViewModel.kt:57-74`; `SignUpViewModel.kt:129-138` |
| F10 | LOW | SignUp "Sign in" link is dead when SignUp was reached from Welcome (`popBackStack(AUTH_SIGN_IN, inclusive=false)` no-op). | `AuthNavGraph.kt` |
| F11 | MED | SignUp proceeds to phone onboarding / home even when `addRole` failed (only a crash report); role stays trigger-default engineer → F2 path. | `SignUpViewModel.kt:129-157` |
| F12 | MED | Sign-out wipes local state **before** the network sign-out; if GLOBAL and LOCAL both fail the device keeps a live session over wiped state; wipe steps are best-effort (`runCatching`) so a failed `setV2OnboardingComplete(false)` leaks the sticky-true onboarding flag to the next account. | `ProfileViewModel.onSignOut`; `SignOutCleanup.kt` |
| F13 | LOW | `DeepLinkHost.engineerStatus` is fetched once per distinct userId and **never reset on sign-out**; same-account re-login keeps the stale status (Jobs-tab gating). Doc comment claims "null when signed out" — not implemented. | `DeepLinkHost.kt:54-65` |
| F14 | MED | Google-only accounts cannot pass the password-only re-auth (`verifyCurrentPassword` = `signInWith(Email)`): change password / change email / delete account are unreachable for them. | `SupabaseAuthRepository.verifyCurrentPassword` |
| F15 | LOW | Email confirmation completes on the web only; the app shows a one-shot message and has no "confirmed, sign in" state. | `SignUpViewModel.kt:158-172` |
| F16 | LOW | Onboarding host has no back stack: Back exits the app; `HOSPITAL_PHONE_ONBOARDING` swallows Back entirely. | `AppNavGraph.kt`; `HospitalPhoneOnboardingScreen.kt` |
| F17 | LOW | `tourSeen` initial `true` (assume seen) and `lastScreen` restore interact with `NeedsRole`/`NeedsOnboarding`: a restored `lastScreen` route is navigated inside main even when the role is unknown. | `SessionViewModel.kt:113-121`; `DeepLinkHost.lastScreen` |
| F18 | LOW | `AuthEffect` flows are `replay=0` by design: an effect emitted while the screen is not collecting (rotation without `configChanges` coverage, process death) is dropped — acceptable because the root gate is the real transition, but `ShowMessage` for email confirmation can be lost. | `SignUpViewModel.kt:59-62` |
| F19 | LOW | Password recovery has no in-app completion path; `/auth/reset` is excluded from App Links on purpose; the user must sign in again manually. | `SupabaseAuthRepository.sendPasswordResetEmail`; `docs/auth/reset.html` |
| F20 | LOW | `HomeHubViewModel` role = `prefsRole ?: profile.activeRole ?: profile.role` — falls back to the trigger-default scalar role when prefs are blank (same root as F2). | `HomeHubViewModel.kt` (read-only) |

Not proven (needs device or CI evidence, not claimed): actual Compose navigation order in F6/F7
(only the ViewModel-level state sequence can be pinned by JVM tests); whether a third-party app
can deliver `EXTRA_ROUTE` on current Android versions given the manifest's intent filters
(F4 is proven at the router level only).

---

## 4. Test-first plan — implementation recipes are provisional

Rule: every row starts with a **red** test on this branch (test-only), then the production
change lands on the Codex branch after Codex review. Nothing below changes `HomeHubScreen.kt`,
`HospitalHomeActions.kt`, `MainNavGraph.kt`, Room/photo files or Gradle files, except where
marked "Codex-owned". The proposed mechanisms below are hypotheses to validate against
current source and race tests, not approved implementation instructions. In particular,
identity fencing must survive same-user re-login (ABA) and suspension inside preference
writes; sign-out ordering must preserve existing draft and outbox isolation guarantees.

| ID | Test (this branch, `app/src/test/kotlin/com/equipseva/app/…`) | Production change (Codex-owned, later) | Acceptance gate |
| --- | --- | --- | --- |
| A1 (F3) | `features/auth/SessionViewModelStateMachineTest`: `same account re-login after sign-out re-bootstraps` — expects `fetchByIdCalls == [A, A]`, second state `Ready`. Characterisation version pins today's `NeedsRole` + 1 call. | Replace `distinctUntilChangedBy { it.userId }` with a sign-out-aware discriminator (e.g. `scan` over `(SignedOut, SignedIn)` transitions) in `SessionViewModel.init`. | Test green; existing zombie tests green; no new `fetchById` on config change. |
| A2 (F2) | Same class: `trigger default profile lands NeedsRole` + new `navigation/AppNavGraphNeedsRoleTest` (Robolectric Compose) asserting `NeedsRole` mounts `RoleSelectScreen`, never `main_host`. | `AppNavGraph`: handle `NeedsRole` → `ROLE_SELECT` host; wire `RoleSelectScreen` (Codex decides placement). `tabRoutesForRole(null)` must not return engineer tabs (return empty / gate). | Cold start and live `NeedsRole` both show RoleSelect; `TabRoutesForRoleTest` updated; plan rule satisfied. |
| A3 (F4) | `navigation/DeepLinkRouterInjectionTest` (Robolectric): `EXTRA_ROUTE` `founder/dashboard` is currently forwarded (characterisation), target expectation: **dropped**; `navigation/DeepLinkHostTest`: links dispatched while signed out are dropped on the next sign-in. | `DeepLinkRouter`: allow-list `EXTRA_ROUTE` against `routeForParts`-style patterns (job/chat/engineer/notifications only); `DeepLinkHost`: clear buffered events on `SignedOut`; optional: verify FCM-origin via a signed extra. | Injection test green; existing `DeepLinkRouterTest` green; notification taps still route (manual check on device). |
| A4 (F9) | Generation-aware stale-write tests for RoleSelect, SignUp and Profile writers: A→B, A→signed-out→A, and A→B→A while a role RPC is suspended; also suspend immediately before preference publication and switch sessions. An old generation must publish no role/onboarding/navigation effect into the new session. Characterise current failures first. | Capture an identity lease containing account and session generation before work. Fence publication atomically against the same generation (or use session-owned storage/serialised mutation); a userId re-read alone has ABA and check-to-write gaps. Validate cancellation and cleanup paths under the same lease. Exact mechanism is provisional. | All three writers reject old generations, including same-account re-login and switch during setter suspension; fresh-generation writes still succeed. Use the unified typed ledger to assert no cross-method stale writes. |
| A5 (F5) | `core/auth/SupabaseAuthSessionMappingTest`: `RefreshFailure(NetworkError)` → target `AuthSession.Unknown` (or a new `Degraded`) instead of `SignedOut`; characterisation pins `SignedOut`. | Map `RefreshFailure` to a retained-session state; `SessionViewModel` keeps `Ready` with cached role while a refresh retry runs; sign out only on `NotAuthenticated`. | Offline token expiry no longer clears `activeRole` or navigates to Welcome (INT test with `TestSupabaseClient` MockEngine 5xx). |
| A6 (F8) | Same mapping test: `Authenticated with null user` → target `Unknown`; characterisation pins `SignedIn("")`. `SessionViewModelStateMachineTest`: blank userId never calls `fetchById`. | Guard `user?.id.isNullOrBlank()` → `Unknown` and trigger `retrieveUser`. | No `fetchById("")` ever. |
| A7 (F11) | `features/auth/SignUpViewModelEffectsTest`: `addRole failure surfaces an error and emits no navigation` (target); characterisation pins navigation. | `SignUpViewModel`: on `addRole` failure set `form.errorMessage` (retry) instead of navigating. | Green; analytics still fires only on success. |
| A8 (F1) | `core/data/profile/ProfileFetchFallbackTest` (MockEngine via `TestSupabaseClient`): decode failure + minimal row → `Result.failure` (target) not a synthetic profile. | `SupabaseProfileRepository.fetchById`: distinguish "no row" (404/empty) from "select failed" (throw); only an authenticated empty result is `success(null)`. | No wipe on RLS/decode failure; deleted-account path unchanged for a real empty row. |
| A9 (F7) | `SessionViewModelStateMachineTest`: for a fresh sign-in of an onboarded account, observe all gate emissions while `RecordingUserPrefs.afterActiveRolePublication` parks the setter after role publication but before return. Characterise the intermediate `NeedsOnboarding`; target is no incorrect onboarding emission before `Ready`. The before-write hook does not expose this state. | Publish generation-validated onboarding truth before role, or change the gate so bootstrapping suppresses intermediate states even when role is nonblank. Merely leaving `bootstrapping=true` is insufficient under the current gate. Validate whichever provisional mechanism is chosen. | Test drives the collector during the after-publication pause, asserts no `NeedsOnboarding`, then releases and reaches `Ready`; genuinely incomplete users still reach onboarding and stale generations cannot publish truth. |
| A10 (F13) | `DeepLinkHostTest`: `engineerStatus` resets to null on `SignedOut` and refetches on same-user re-login. | Collect full `sessionState`; null on `SignedOut`. | Green. |
| A11 (F6/F16/F10) | `AuthNavGraph` Robolectric Compose tests: SignUp→"Sign in" from Welcome lands on SIGN_IN; hospital signup lands deterministically on phone onboarding. | `AuthNavGraph`: navigate to SIGN_IN when pop fails; root gate defers to auth host while `HOSPITAL_PHONE_ONBOARDING` is active (already partially guarded). | Green on both cold-start and live paths. |
| A12 (F12) | `core/auth/SignOutOrderingTest`: suspend/fail token revocation and GLOBAL/LOCAL sign-out independently; switch to B and re-login A while old cleanup is paused. Assert old draft/outbox work is immediately fenced, late cleanup cannot erase the new session, and failures leave explicit recoverable UI. Keep `SignOutDraftFenceTest` green. | Preserve the existing immediate draft fence and establish a generation-scoped outbox fence before any network revocation; current outbox clearing/cancellation follows device-token revocation. Then evaluate credential-dependent token revocation, auth invalidation and generation-scoped cleanup separately. Final ordering is a hypothesis until tests; do not move the whole wipe behind network calls or equate network failure with permission to reuse old identity leases. | Old writes are rejected throughout slow/failing network work; new-session state survives late cleanup; GLOBAL/LOCAL failures and failed local clears have deterministic recovery without cross-account cache reuse. |
| A13 (F14) | Product decision for Codex/owner: re-auth for OAuth-only accounts (Google re-prompt or email OTP). | — | Decision recorded. |

Acceptance gates common to every row: (1) the narrow test class is run with
`./gradlew :app:testDebugUnitTest --tests "<class>"` and the Gradle log + JUnit XML counts are
pasted into this document; (2) `git hash-object` blob SHA of each new file recorded; (3) full
`:app:testDebugUnitTest` green before any merge; (4) critic and QA scores recorded only with
that evidence attached.

---

## 5. Original helper-branch resume checklist

Historical recipe for continuing the helper branch only. Codex integration must keep its
current checkout/ownership and consult §8; do not switch a shared dirty checkout merely
to follow this checklist.

1. `git fetch origin && git switch claudedev-auth-audit && git log -1` — confirm the tip matches
   the commit table below.
2. Compile the fixtures: `./gradlew :app:compileDebugUnitTestKotlin` (expect green; fix imports
   if MockK inline mocking of `UserPrefs` complains — the project already mocks final classes
   `DeviceTokenRegistrar` and `CrashReporter`).
3. Write the test classes in the order A1, A2 (VM part), A3, A4, A5/A6, A7, A9, A10 — each as a
   **characterisation** test first (pins today's behaviour, named honestly), with the target
   expectation in a comment or a second `@Ignore`d test. Use `Dispatchers.setMain(StandardTestDispatcher())`
   + `runTest(dispatcher)` + `runCurrent()`; Robolectric `@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])`
   for anything that needs `Intent`/`Uri`.
4. Run only the new classes; save the log under the scratchpad and paste counts here.
5. Commit per milestone (`test(auth-audit): …` + `Validation:` paragraph), push with
   `git push -u origin claudedev-auth-audit` — the branch's upstream was the Codex branch at
   creation; **never bare `git push`** until the upstream is switched.
6. Run critic and QA reviewers; record scores only with the evidence from step 4.
7. Tell the Codex session: `git fetch origin claudedev-auth-audit` and read this file.

---

## 6. Merge points (for Codex)

All changes are **new files**; no existing file is modified. Cherry-pick or merge is conflict-free
against `4a2677ea`.

| Path | Purpose |
| --- | --- |
| `docs/HANDOFF_CLAUDEDEV_AUTH_AUDIT.md` | this document |
| `app/src/test/kotlin/com/equipseva/app/testing/RecordingUserPrefs.kt` | UserPrefs test double (uncompiled at helper handoff; integration validation in §8) |
| `app/src/test/kotlin/com/equipseva/app/testing/AuthAuditFixtures.kt` | Profile fixtures (uncompiled at helper handoff; integration validation in §8) |

Codex context at cut time: `4a2677ea` "feat: persist repair photo delivery state" (Room v5) is the
tip; the helper branch `claudedev-help` is already merged (`1054e473`). Nothing here touches
that work.

## 7. Commit log (this branch)

| Milestone | Commit | Content | Validation |
| --- | --- | --- | --- |
| m1 | `fc5ece0446b774b82d496822ce7d0d0e9e4ebc17` | audit doc + two fixtures | **none on helper branch** — not compiled, not run; no CI result recorded (branch excluded from Android/secret-scan/evidence push filters) |

## 8. Codex integration correction — 2026-09-10

The fixture double now offers distinct before-write and after-role-publication pauses,
records typed writes across all supported setters, and matches production blank-route
normalisation. `confirmedProfile` describes a normalised confirmed test state, not the
guaranteed result of every role RPC. A4, A9 and A12 now state generation-aware fencing,
the actual intermediate-publication test point, and preservation of immediate local
identity fencing before network work. All production mechanisms in §4 remain provisional.

Focused validation (fixture utilities only):

```text
.\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.testing.RecordingUserPrefsTest --rerun-tasks --max-workers=2 --no-configuration-cache
BUILD SUCCESSFUL in 1m 39s
45 actionable tasks: 45 executed
JUnit XML: 4 tests, 0 failures, 0 errors, 0 skipped
```

XML: `app/build/test-results/testDebugUnitTest/TEST-com.equipseva.app.testing.RecordingUserPrefsTest.xml`
(timestamp `2026-09-10T14:56:02.688Z`). Preserved log and machine-readable summary:
`../verification/auth-audit-fixture-final.log` and
`../verification/auth-audit-fixture-final.json`. Four tests cover both suspension boundaries,
cross-setter ordering including repeated writes/clears, and raw versus published route
values. The command also compiled both fixture files. Its result is not a passing auth
state-machine suite, production fix, full regression run, device run, or reviewer score.

Source Git blob hashes for the focused run:

| File | `git hash-object` |
| --- | --- |
| `AuthAuditFixtures.kt` | `4b16cc5ca3fce182bad626d90b8d92e1f062cd4a` |
| `RecordingUserPrefs.kt` | `1404848719a8df9f7ac6bb2ac19f8cb0ba9a62c0` |
| `RecordingUserPrefsTest.kt` | `d40f74c99d5f03f28566c37fa3674b56640ed9cd` |
