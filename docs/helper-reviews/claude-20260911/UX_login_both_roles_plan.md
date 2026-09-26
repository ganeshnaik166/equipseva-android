# Login + both-role UX plan (review and design proposal, no code changed)

Reviewer: Claude helper, branch `claudedev-next-review-20260911`, base
`1e770076358e74f6f40a99a4907f831da59e791c`. Sources: direct reads of the auth/navigation
files (hashes in the A3 and A4/A12 reports) and three static exploration passes over the
hospital, engineer and auth/onboarding screens at this base (file:line citations from those
passes are marked "expl." and were not all re-read line by line). Nothing was rendered,
executed on a device, or validated with users. Existing routes, RPCs and rules are described
as they are; anything that would change a rule is listed in §6 as an owner decision.

Column meaning in the tables: **Prereq** = what the client enforces before the action;
**Pending** = what the user sees while the request is in flight; **Error / Offline** = what is
shown on failure (the app has no connectivity probe anywhere, so "offline" is always
inferred from a failed call); **Cancel** = Back or explicit exit; **Restart** = state after
process death; **Next** = destination on success.

## 1. Welcome, sign-in, confirmation, Google, role, setup, account switching

| # | Action (screen) | Prereq | Pending | Error / Offline | Cancel | Restart | Next | Gaps found |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L1 | Welcome → Sign in / Create account (`WelcomeScreen`) | none | n/a | n/a | Back exits app | nothing to lose | `auth/sign_in`, `auth/sign_up` | no `verticalScroll` (CTAs can leave the screen at large text); "Create account" is a `Box.clickable` without button role and a fixed 52 dp height (expl. L113-120); legal links are one node (expl. L158) |
| L2 | Email sign-in (`SignInScreen`, `SignInViewModel` L57-83) | valid email, non-blank password | fields and buttons disabled; **no spinner** | `ErrorBanner` without retry/dismiss; field errors; network → "Network problem. Check your connection and retry." (hardcoded) | Back → Welcome | form lost (no `SavedStateHandle`) | `SignedIn` → root gate; the `NavigateToHome` effect is informational | link targets ("Forgot password?", "Create one") are bare text without button role or 48 dp target (expl. L130-177) |
| L3 | Google sign-in (`SignInViewModel` L91-124) | web client id configured | as L2 | `NotConfigured` → hardcoded copy; `Error` → provider message; token exchange failure → network copy | picker cancel → silent reset | as L2 | as L2 | first-time Google accounts arrive with the trigger's unconfirmed engineer role → A2 chooser (correct); no "which account" confirmation |
| L4 | Create account (`SignUpScreen`, `SignUpViewModel` L85-181) | name ≥ 2 chars with a letter, valid email, strong password, role tile | disabled controls; **no spinner** | banner (role missing is a banner, not inline); network copy | Back; "Sign in" link now works from Welcome (A2, `AuthNavGraph` L46-50) | form lost | `AutoSignedIn` → root admits the account; the auth entry is retired, which can cancel `addRole` → chooser (accepted A2 fallback) | `addRole` failure only crash-reported (A4-04); role tiles lose semantics while disabled and are not grouped (expl. L235-243) |
| L5 | Email confirmation (`SignUpViewModel` L158-172) | Supabase "confirm email" on | n/a | n/a | n/a | message lost | form reset + **snackbar** "Verification link sent to …" | no persistent "check your inbox" state, no resend, the typed email disappears, confirmation completes on the web with no return path |
| L6 | Forgot password (`ForgotPasswordScreen`) | valid email | disabled; no spinner | banner; network copy | Back | lost | `SentBlock` (check icon + copy) | no resend or cooldown; the form→success swap is not announced (no live region); completes on the web page, app has no "password changed" state |
| L7 | Role confirmation (A2 `RoleSelectScreen`, `RoleSelectViewModel`) | `SignedIn` owner; server profile without a confirmed hospital/engineer role | spinner in the button, cards disabled, "Saving…" | three mapped errors (session / network / save) in an announced banner; CTA becomes "Try again" | **explicit sign-out** (no Back handler; system Back on the root gate is not verified on device) | choice lost; `add_role` is durable, root re-fetch recovers | "Saved" + "Check setup again" → root refresh → onboarding or MAIN | dark-theme button contrast 2.38:1 (open A2 blocker); screen uses light tokens on a dark scheme |
| L8 | Recovery gate (`SessionRecoveryScreen`, `AppNavGraph` L131-154) | unknown/admin/deferred role or owner mismatch | spinner + "Preparing…" / "Signing out…" | "Try again" | "Sign out" when an owner is known | n/a | root refresh | no heading, no live region on the status text; blank-uid sessions have no sign-out (owner null) |
| L9 | Hospital setup: phone, state, district (`HospitalOnboardingScreen`) | routable phone, state, district | "Saving…", fields disabled, no spinner | plain red text, **no retry, no live region**; network copy | **no exit at all** (no top bar, no Back handling, no sign-out) | lost | `updateBasicInfo` → root refresh → MAIN | no `imePadding`; the legacy phone screen is now a dead redirect (A2) |
| L10 | Engineer base setup (`EngineerOnboardingScreen`) | as L9 | as L9 | as L9 | as L9 | lost | root refresh → payout onboarding | CTA "Save and start KYC" but the next gate is payout, not KYC |
| L11 | Engineer payout onboarding (`EngineerPayoutOnboardingScreen`) | **both** UPI and bank valid (VPA regex, IFSC regex, 9–18 digit account, re-typed match) | "Saving…"; partial-save banner names what saved | plain red text; IFSC lookup shows looking-up / resolved / unverified | top-bar back → sign-out dialog; **system Back bypasses the dialog** | lost (server saves per section, so partial progress survives) | root refresh → MAIN | no `imePadding` on the longest form in the product; most copy hardcoded; initial `loading` never rendered |
| L12 | KYC (`KycScreen`, post-login) | step gates: verified email; Aadhaar/PAN valid + docs + ≥1 cert + attestation; Play Integrity on release | per-doc upload state; "will upload when back online" via the photo outbox | error + **retry**; per-doc "tap to retry" | Back | `SavedStateHandle` restores every step | `KYC_SUBMITTED` → Home | Jobs-tab gate stays stale after a decision (`refreshEngineerStatus` has no callers); the `lastScreen` pin is never set (dead restore path) |
| L13 | Sign out (Profile) | confirm dialog | "Signing out…" | `toUserMessage()`; wipe already ran (A4-03) | dismiss | n/a | `SignedOut` → auth gate (A2 retires the entry) | two sign-out implementations (A4-03) |
| L14 | Switch role (Profile role editor) | role in `activeRoles`; not already current | spinner + "Saving" | `toUserMessage()` | scrim / Back | lost | `add_role` → `set_active_role` → `invalidate` → root refresh → MAIN for the new role | options announce as cards, selection by colour only, no radio group (expl. L1252-1325); mirror write redundant (A4-05) |
| L15 | Replace account A → B | n/a | A2 resolving overlay blocks input | n/a | n/a | n/a | B's own entry | deep-link replay and cleanup races (A3-02, A4-01, A4-02) |

## 2. Hospital journey (request → bids → service → evidence → payment / dispute)

Screens (expl.): `HomeHubScreen` + `HospitalHomeActions`, `RequestServiceScreen`,
`RequestSentScreen`, `HospitalActiveJobsScreen`, `RepairJobDetailScreen` (bids, order
summary, escrow sheet, tracking, evidence, completion, dispute, cancel), `DsrScreen`,
`HospitalMyDisputesScreen`. There is no separate "confirm terms", "track visit" or
"payment status" screen; those are sections and sheets of the job detail.

| # | Action | Prereq (client) | Pending | Error / Offline | Cancel | Restart | Next |
| --- | --- | --- | --- | --- | --- | --- | --- |
| H1 | Home → Request service | role hospital (validated by root) | n/a | hub fetch errors swallowed; pending banner exists for AMC only, **not for a stranded escrow payment** | n/a | `RefreshOnReturn` | `hospital/request_service` |
| H2 | Request service: fill and submit | signed in; **hospital phone present** (hard block, points to Profile); slot; issue ≥ 10 chars; address ≥ 5; optional budget > 0; category in the 5 allowed | "Submitting…"; photo upload spinner | error banner; draft-failure banner **with Retry**; network → banner; **no outbox for job creation** | Back (no discard confirm); Keep/Discard bar for a recovered draft | **best in app**: `SavedStateHandle` + owner/session-fenced DataStore draft (30 days), photo-picker correlation survives | `hospital/request_sent?jobId&jobNumber` |
| H3 | Request sent | n/a | n/a | n/a | "Back to home" | static | job detail or Home |
| H4 | My repair jobs (bookings) | signed in | pull-to-refresh | banner **without retry**; refresh failure with cached rows is silent | n/a | filter resets | job detail; "Post new job" |
| H5 | Compare and accept a bid | hospital, status `requested`, no accept in flight | "Accepting…" on that card | snackbar; **no outbox** (an offline accept just fails) | n/a | sheet flags `rememberSaveable`; VM sheet state not saved | auto-opens the order summary → escrow payment |
| H6 | Confirm terms → pay escrow (Razorpay) | escrow `pending`, activity present | "Processing…"; pending marker written before checkout | cancelled/failed clear the marker; **success but verify failed keeps the marker** for the reconciler | close sheet | marker survives; **no UI shows the in-flight payment** after restart | escrow `held` |
| H7 | Track the visit | assigned bid exists | status stepper | n/a | n/a | n/a | message engineer (chat); cost-revision decision sheet (realtime) |
| H8 | Review evidence | status `completed` for after-photos; DSR when engineer assigned and status ≥ in progress | n/a | photo URL failures dropped silently; DSR error **with retry** | n/a | DSR fields `rememberSaveable` | countersign DSR (`hospital_sign_dsr`, name/role ≥ 3 chars) |
| H9 | Completion: release, rate, invoice, book again | escrow `held` + job `completed`; stars 1–5 | "Confirming…" etc. | snackbar; **no outbox** for release/dispute | n/a | n/a | rating → "Book this engineer again" (request prefilled by engineer id, informational only) |
| H10 | Dispute / cancel | held + completed + in dispute window; cancel from `requested`/`assigned`, reason ≥ 10 chars when assigned | "Cancelling…" | snackbar | keep job | n/a | escrow `in_dispute`; disputes list |

Hospital-side observations that shape the slices: every money or decision write
(accept, pay, release, dispute, create job) has no queue and no retry affordance; the
bookings list has **zero** string resources; the stepper uses fixed 56 dp columns and the
primary button component fixes its height (expl. `EsBtn.kt` L71-74), so labels clip at large
text and in Hindi/Telugu; evidence photos have `contentDescription = null` (invisible to
TalkBack); the order-summary GST split is computed client-side while the charged amount comes
from the server (they agree only by server construction).

## 3. Engineer journey (discovery → bid → assignment → work → evidence → payment)

| # | Action | Prereq (client) | Pending | Error / Offline | Cancel | Restart | Next |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | Home → Find work | role engineer (validated) | n/a | fetch errors swallowed | n/a | `RefreshOnReturn` | jobs hub |
| E2 | Jobs hub | **Verified** for all 12 tiles; Pending/Rejected/none → hero with copy | spinner | **any fetch error renders "Become a verified engineer"** (error folded into `NotEngineer`); no retry | n/a | n/a | feed, my bids, active work, earnings, AMC visits, disputes, … |
| E3 | Jobs tab (bottom nav) | `engineerStatus == Verified` else snackbar | n/a | stale for the whole session after a KYC decision | n/a | n/a | hub |
| E4 | Discover feed | base coordinates for radius search (pre-empted with a clear message) | shimmer, pull-to-refresh, paging | banner **without retry** | n/a | query/radius lost | job detail |
| E5 | Place / edit / withdraw bid | **phone present** and **KYC verified** (stricter than KYC itself, which does not require phone); amount 1–1 crore, ETA 1–720 h; withdraw only from `Pending` | "Queued — back online" when the outbox holds it | failure → **outbox** + pill; snackbar | n/a | composer fields `rememberSaveable` | own-bid card; my bids |
| E6 | Assignment → active work | bid accepted | n/a | banner without retry; queued-status pill | n/a | n/a | job detail |
| E7 | Check in | assigned engineer identity; status `assigned`/`en_route`; GPS fix; ≥ 1 before-photo (max 4); geofence enforced **server-side** (250 m) | "Checking in…" / queued | failure → outbox (status) with optimistic flip; photos → photo outbox | n/a | picked URIs `rememberSaveable` | `in_progress` |
| E8 | Work: revise quote, message | engineer, no pending revision, status `en_route`/`in_progress` | sheet | snackbar | close | n/a | hospital decides (realtime) |
| E9 | Submit evidence: photos → `photo_upload` → `evidence_register`; DSR | ≥ 1 after-photo for "Mark done"; DSR: summary 20–5000 chars, calibration verdict required when performed, serial ≤ 64 | queued pill; DSR "Submitting…" | photo/evidence: outbox with poison-drop **system notification only**; DSR: inline error + retry, **no outbox** | n/a | DSR fields `rememberSaveable` | `completed`; DSR awaiting hospital |
| E10 | Payout status / earnings | none | pull-to-refresh | per-slice isolation; banner without retry; "Fix method" CTA **routes to the legacy generic settings form**, not the payout-method screen (expl. `MainNavGraph` L811 vs L635) | n/a | lost | payout method screen |
| E11 | Disputes received | none | pull-to-refresh | error + retry | n/a | lost | job detail (reply sheet) |

Engineer-side observations: outbox `attempts`/`lastError` are never shown in-app (only a
poison-drop system notification, skipped without the notification permission); the Room v5
photo-delivery state machine is registered but not wired; the jobs hub and active-work
screens are entirely untranslated; the payout-method screen has a fixed 44 dp mode toggle and
no state restore.

## 4. Smallest useful redesign slices, in priority order

Each slice is bounded to existing behaviour (no policy change), lists the files it would
touch, and the acceptance checks it must pass. Slice 0 is the coordinator's open A2 item and
is listed only because everything after it inherits the same token problem.

| Slice | Change | Files | Acceptance checks (all four dimensions) |
| --- | --- | --- | --- |
| S0 (owned by A2) | RoleSelect button explicit foreground; dark render test | `RoleSelectScreen.kt`, `RoleSelectScreenUiTest.kt` | dark-theme capture ≥ 4.5:1 on the CTA; EN/HI/TE captures unchanged |
| S1 | **Exits from mandatory setup**: add `onSignOut` to the onboarding slot and a top bar with sign-out on hospital/engineer base setup; make system Back on payout setup open the same dialog; remove the inert back arrow on the legacy phone screen | `AppNavGraph.kt` (slot signature), `RootSessionHost.kt` slot type, `HospitalOnboardingScreen.kt`, `EngineerOnboardingScreen.kt`, `EngineerPayoutOnboardingScreen.kt`, `HospitalPhoneOnboardingScreen.kt`, `RootSessionHostTest.kt` | root test: onboarding slot exposes sign-out and it is owner-guarded; TalkBack: no focusable no-op control; large text: exit reachable after scrolling; HI/TE: reuse `root_session_sign_out` |
| S2 | **Honest in-flight and retry states** on the auth graph: spinner in the primary button while submitting; `ErrorBanner` gains `onRetry`; live region on the forgot-password success block; persistent "check your inbox" state with the typed email and a resend action gated by Supabase's own rate limit copy | `SignInScreen.kt`, `SignUpScreen.kt`, `ForgotPasswordScreen.kt`, `ErrorBanner.kt`, `SignUpViewModel.kt` (state only) | Compose tests: submitting shows progress and disables once; error banner retry re-submits once; success block announced; strings in all three locales |
| S3 | **Keyboard and text scale hygiene**: `imePadding()` on the four onboarding forms; `heightIn(min)` instead of fixed height in `EsBtn`, `EsTopBar`, the Welcome CTA, the request-service submit button, the payout mode toggle, the job-detail stepper columns | `EsBtn.kt`, `ESTopBar.kt`, `WelcomeScreen.kt`, `RequestServiceScreen.kt`, `EngineerPayoutMethodScreen.kt`, `RepairJobDetailScreen.kt`, onboarding screens | Robolectric captures at 320 dp / fontScale 2.0 in EN/HI/TE with no clipped text (the A2 test pattern); no fixed `.height` on any text-bearing control in those files |
| S4 | **Localise the auth and setup copy**: move the Kotlin literals of L1–L11 into resources (`ErrorBanner` messages included) and translate the 47 auth/onboarding keys that are English in `values-hi`/`values-te`; keep the A2 files as the reference quality | `SignInViewModel.kt`, `SignUpViewModel.kt`, `ForgotPasswordViewModel.kt`, `AuthError.kt`, `DataError.kt`, the four onboarding screens, `values*/strings.xml` | lint: no hardcoded text in those files; key-and-value diff shows zero English fallbacks for those prefixes; human review of the translations (H) |
| S5 | **Hospital money-path visibility**: surface the pending escrow marker on Home and job detail after restart; add retry affordances to accept/release/dispute snackbars; localise the bookings list and the escrow/payout status helpers | `HomeHubScreen.kt`, `RepairJobDetailScreen.kt`, `HospitalActiveJobsScreen.kt`, strings | Compose: marker card visible with a pending marker; retry re-issues the same RPC once; HI/TE captures of the bookings list |
| S6 | **Engineer eligibility truth**: distinguish fetch error from "not an engineer" in the jobs hub (retry state); call the existing `refreshEngineerStatus()` after `KYC_SUBMITTED` and on return from KYC; route the earnings "Fix method" CTA to the payout-method screen | `EngineerJobsHubScreen.kt`, `MainNavGraph.kt` (after the GPT helper's A10 lands), `EarningsScreen.kt` | tests: error → retry hero, verified stays verified on a failed refresh; Jobs tab reflects a decision without restart; CTA route asserted |
| S7 | **Evidence accessibility**: `contentDescription` on repair photos ("Before photo 1 of 4"), 48 dp icon targets, announce queued/poison-drop state in-app (read `attempts`/`lastError`) | `RepairJobDetailScreen.kt`, `OutboxDao.kt` (new query), pill components | TalkBack: photos and pills announced; unit: failed count query |
| S8 | **Offline chrome**: a connectivity observer feeding the existing unused `OfflineBanner`, shown on the auth graph and the two journeys; keep "will submit when back online" copy for queued writes | `core/network` (new observer), `AppNavGraph.kt`, `MainNavGraph.kt`, `OfflineBanner.kt` | Robolectric: banner appears when the observer reports offline; no behaviour change to writes |

Recommended order: S0 → S1 → S2 → S3 → S4 (these four are pure presentation and unblock every
later visual test) → S6 (functional defects on the engineer path) → S5 → S7 → S8. S5–S8 touch
screens the coordinator has not redesigned yet and should wait for the M2a prototype review.

## 5. Cross-cutting checks to run on every slice

- **Large text**: 320 dp × fontScale 2.0 captures in EN/HI/TE (the A2 harness already does
  this for RoleSelect); fail on any `.height(x.dp)` wrapping text, any ellipsis on a primary
  action, any unreachable CTA without scrolling.
- **TalkBack**: every actionable element has a role (`Role.Button`/`RadioButton`), 48 dp
  target, and a label; radio choices are in a `selectableGroup`; status changes (errors,
  success, loading → retry) carry `liveRegion = Polite`; no focusable control that does
  nothing; decorative icons stay `null`. Device pass required for order and announcements (H/D
  evidence in the QA matrix).
- **English / Hindi / Telugu**: key presence is already 100 %; the real check is value
  presence (722 of 757 `strings.xml` values are still English in both locales) and Kotlin
  literals (32 in auth/onboarding/navigation). Include a human translation review; JVM
  captures prove layout, not language.
- **Dark theme**: the app defaults to `ThemeMode.Light` and only follows the system when the
  user picks "System". Auth and onboarding screens hardcode light tokens (`PaperDefault`,
  `Color.White`, `SevaInk*`) while error containers, radio buttons and the recovery screen
  follow the scheme, so dark mode renders mixed surfaces. Per slice: no hardcoded light surface
  on a screen that also uses `MaterialTheme.colorScheme`; contrast ≥ 4.5:1 on text and ≥ 3:1 on
  icons in both schemes; one dark capture per redesigned screen.

## 6. Owner decisions required before some slices (not decided here)

1. Repeat booking: "Book this engineer again" prefills only the header; the request has no
   target engineer. Keep the copy honest or add a server invitation contract (Codex inventory
   gap 3).
2. Deep link received while signed out: remember for the same process or drop (A3, O1).
3. Re-authentication for Google-only accounts before password/email change and account
   deletion (the current re-auth is password-only).
4. Phone requirement: KYC does not require a phone, bidding does; the hospital request form
   requires it too. Decide where the phone is collected once.
5. Email confirmation: whether to add an in-app "confirmed, sign in" return path (App Link on
   the confirmation redirect) or keep the web-only flow.
6. Payout readiness on a failed readiness RPC: explicit checking/retry state versus the current
   "treat unknown as complete" (A8, item 3).
