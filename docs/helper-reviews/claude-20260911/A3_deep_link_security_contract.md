# A3 — Deep-link security contract (review only, no code changed)

Reviewer: Claude helper, branch `claudedev-next-review-20260911`, base
`1e770076358e74f6f40a99a4907f831da59e791c` (Codex A2 WIP save checkpoint, 2026-09-11).
Scope: `MainActivity`, `DeepLinkRouter`, `NotificationDeepLink`, `DeepLinkHost`,
`EquipSevaMessagingService`, the deep-link sinks in `MainNavGraph`, the inbox tap in
`NotificationsScreen`, the manifest, and the server-side notification insert/push path
as far as the repo shows it. Every line number below is from the files at the hashes in
§7. Nothing here was executed on a device; "reproduction" steps are instructions for the
coordinator, to be run on a debug build only.

None of the files traced here were changed by A1 or A2 (`git diff 4a2677ea..1e770076
--name-status -- app/src/main` lists none of them), so every finding is an **existing**
defect, not an A2 regression. The GPT-5.3 helper owns `DeepLinkHost.engineerStatus` (A10)
and a parser edge-case test file; neither is duplicated here.

## 1. Inventory

### 1.1 Entry points and the single sink

| Step | Code | What it trusts |
| --- | --- | --- |
| FCM message received | `EquipSevaMessagingService.onMessageReceived` L43-132: `route = NotificationDeepLink.routeFor(data["kind"], data)` L85; explicit `Intent(this, MainActivity)` with `CLEAR_TOP or SINGLE_TOP` L86-90; `putExtra(EXTRA_ROUTE, route)`; immutable `PendingIntent` keyed by `messageId.hashCode()` L91-98 | The route is resolved at **receive** time, under whatever account is signed in then, and frozen into the tray entry |
| Cold start | `MainActivity.onCreate` L63 `deepLinkRouter.dispatch(intent)` unconditionally (no `savedInstanceState == null` check) | Whatever intent recreated the activity |
| Warm start | `MainActivity.onNewIntent` L103-107: `setIntent(intent)` then dispatch | Same, and the new intent becomes the recreation intent |
| App Link | manifest L72-84 (`https`, hosts `equipseva.com`/`www.`, `pathPrefix /job/ /chat/ /engineer/`, `path /engineers /notifications`, `autoVerify`) → `DeepLinkRouter.routeForParts` L75-93 strict whitelist (RPR code / UUID regex) | Verified host + strict id shapes. This path is sound |
| Router | `DeepLinkRouter.dispatch` L38-44: `intent.getStringExtra(EXTRA_ROUTE)?.takeIf { isNotBlank() } ?: routeFor(intent.data)`; `Channel(Channel.BUFFERED)` on a `@Singleton` L24-36 | **`EXTRA_ROUTE` is forwarded verbatim**; only blankness is checked. The buffer (64 slots) survives sign-out |
| Host | `DeepLinkHost` L111-119 re-wraps every router event into its own buffered channel; created by `hiltViewModel<DeepLinkHost>()` in `MainNavGraph` L169, so since A2 it is scoped to the `root_main/{owner}/{role}` entry (one host per login) | The KDoc L25-33 says the host "owns the decision of whether a deep-link event should actually navigate"; it makes no decision |
| Consumer | `MainNavGraph` L219-231: `runCatching { navController.navigate(event.route) }` | Any string that happens to match a registered route navigates; `runCatching` only prevents a crash |
| Restore pin | `MainNavGraph` L196-215: `navController.navigate(pinned)` from `UserPrefs.lastScreen`, skip only `KYC` when Verified | A device-global pref (writers: `KycViewModel` L76/L80/L96) |
| Inbox tap | `NotificationsScreen` L176-184: `NotificationDeepLink.routeFor(row.kind, row.data)` → `onOpenRoute` → `MainNavGraph` L677-681 `navController.navigate(route)` (no `runCatching`); else legacy `row.deepLink` → `routeNotificationDeepLink` L1241-1252 → `resolveNotificationDeepLink` L1273-1302 (allow-list: `app://`/`equipseva://` `repair/<uuid>`, `chat/<uuid>`, bare `home|repair|profile|chat`) | Server-stored row content; the legacy resolver is a real allow-list |

Other producers of `EXTRA_ROUTE` in `app/src/main`: none (grep). Other collectors of
`DeepLinkRouter.events`: none besides `DeepLinkHost`.

### 1.2 Notification kinds (34) and exact routes

Source: `NotificationDeepLink.routeFor` L53-156 and constants L167-227. ID validation:
`UUID_REGEX` L34-35 (RFC 4122 hex form, case-insensitive), `JOB_CODE_REGEX` `^RPR-\d{1,8}$`
L42 (case-insensitive). Unknown, null or blank kind, or a missing/invalid id, returns `null`
(no `EXTRA_ROUTE`; the tap opens the default landing).

| Destination route (built by `Routes.*`) | Id key and shape | Kinds |
| --- | --- | --- |
| `repair/detail/{id}` | `repair_job_id` = UUID **or** `RPR-NNNNN` | `repair_bid_new`, `repair_bid_accepted`, `repair_bid_rejected`, `repair_job_cancelled`, `rate_engineer`, `rate_hospital`, `cost_revision_proposed`, `cost_revision_approved`, `cost_revision_rejected`, `warranty_covered`, `warranty_fee_waived`, `escrow_dispute_opened`, `escrow_engineer_responded`, `escrow_dispute_resolved`, `amc_visit_assigned`, `amc_visit_engineer_assigned`, `amc_visit_engineer_changed`, `engineer_payout_processed`, `engineer_payout_failed` (19) |
| `chat/detail/{id}` | `conversation_id` = UUID | `chat_message_new` |
| `engineers/public/{id}` | `engineer_id` = UUID | `amc_loyal_pair_nudge` |
| `amc/contract/{id}` | `amc_contract_id` = UUID | `amc_sla_breach`, `amc_visit_pending_assignment`, `amc_renewal_due` |
| `profile/kyc` | none | `kyc_status_changed` |
| `home` | none | `cash_survey`, `spot_audit_invited`, `commission_tier_upgraded` |
| `profile` | none | `engineer_auto_suspended`, `engineer_suspension_cleared` |
| `engineer/amc_visits` | none | `amc_visit_unassigned` |
| **`founder/cash_suspended`**, **`founder/escrow_disputes`**, **`founder/amc_escalations`** | none | `admin_engineer_auto_suspended`, `admin_escrow_dispute_opened`, `amc_admin_escalation_raised` |

Existing coverage: `NotificationDeepLinkTest` (14), `NotificationDeepLinkV2Test` (22),
`NotificationDeepLinkPayoutTest` (6), `NotificationKindDriftGuardTest` (1, every server kind
routed or deliberately inboxed), `DeepLinkRouterTest` (11, `routeForParts` only),
`ResolveNotificationDeepLinkTest` (12), `ResolveNotifyIdTest` (8). There is **no** test of
`DeepLinkRouter.dispatch`, `DeepLinkHost` event delivery, `MainActivity` dispatch, or the
`MainNavGraph` sinks.

### 1.3 Server side, as far as the repo shows

- `notifications` rows are inserted only by SECURITY DEFINER trigger/RPC functions (38
  migration files contain `INSERT INTO public.notifications`; no `CREATE POLICY … FOR INSERT`
  on the table was found). UPDATE is limited to own rows with `WITH CHECK (auth.uid() =
  user_id)` (`20260424104624_round4…sql` L67-68); DELETE is revoked from `authenticated`/`anon`
  (`20260428320000…sql` L24). A client therefore cannot forge a row for another user through
  the table.
- Push dispatch: `notifications_dispatch_push()` posts `to_jsonb(NEW)` as `record`
  (`20260425020000…sql` L47-90). The edge function `send_push_notification` **re-fetches the
  row by id** and reads `user_id, title, body, data, kind` from the database
  (`supabase/functions/send_push_notification/index.ts` L275-312, "never trust the request
  body's user_id"), then stringifies `data` into the FCM data map (L178-189).
- Not verified in this pass: whether the FCM data map includes the recipient `user_id`
  (needed for the fix in §3), and whether every inserting function derives `data.*` ids only
  from rows the recipient is a party to. Those are server review items (§4).

## 2. Findings

Severity scale: HIGH = cross-identity or privileged UI reachable by an untrusted party;
MED = wrong navigation or lost work under realistic conditions; LOW = defect without
security impact. "Owner" is who should land the change.

### A3-01 · HIGH · `EXTRA_ROUTE` is an unauthenticated navigation command

- Evidence: manifest L43-48 (`exported="true"`, required for the launcher and App Links);
  `DeepLinkRouter.dispatch` L40-43; `DeepLinkHost` L115; `MainNavGraph` L228. No allow-list,
  no role check, no session check on the extra. The FCM service is the only legitimate
  producer, but the receiving activity cannot distinguish its own `PendingIntent` from an
  explicit intent sent by any installed app; there is no way to prove the origin of an extra,
  and adding an "FCM-origin" marker extra would be trivially forged.
- Reproduction (debug build, signed in as any hospital or engineer):
  ```
  adb shell am start -n com.equipseva.app/.MainActivity --es com.equipseva.app.deeplink.ROUTE founder/dashboard
  adb shell am start -n com.equipseva.app/.MainActivity --es com.equipseva.app.deeplink.ROUTE "founder/integrity?user=00000000-0000-4000-8000-000000000001&name=Attacker%20text"
  adb shell am start -n com.equipseva.app/.MainActivity --es com.equipseva.app.deeplink.ROUTE profile/engineer_payout_method
  ```
  Expected today: the founder dashboard UI mounts (its RPCs deny data for non-founders via
  `is_founder()`; the screens still render with attacker-chosen query text on the integrity
  route), and any signed-in user can be steered into payout/email/password screens from a
  third-party app (social-engineering surface). A route with a foreign job id renders the job
  detail shell and then fails on RLS.
- Fix (test-first): stop shipping a pre-resolved route. The service should put `kind` and the
  raw id fields (plus the recipient `user_id`, §3) into the intent; `DeepLinkRouter.dispatch`
  re-runs `NotificationDeepLink.routeFor` so the parser is the single allow-list for both
  push and https. If `EXTRA_ROUTE` must stay for compatibility, accept it only when
  `DeepLinkPolicy.isExternallyAllowed(route)` (the App-Link route classes plus the fixed
  notification destinations) and **deny `founder/*`, `root_*`, `auth*`, onboarding and every
  parameterised route not in the table** in §3. Keep `runCatching` as the last line of defence,
  not the first. Founder queues stay reachable only from the authenticated inbox/profile after
  `Profile.isFounder()`.
- Owner: coordinator (A3). Tests: T-A3-01, T-A3-03, T-A3-06.

### A3-02 · HIGH · Deep links replay across login boundaries

- Evidence: singleton buffered channel `DeepLinkRouter` L35 with no clear/reset API; host is
  created only while the MAIN gate is mounted (`MainNavGraph` L169) and collects whatever the
  router buffered (`DeepLinkHost` L111-119); no producer or consumer looks at
  `AuthRepository.sessionState`; nothing cancels posted tray notifications on sign-out (grep:
  no `NotificationManagerCompat.cancelAll`/`cancel(` in `app/src/main`; `SignOutCleanup`
  L55-95 does not touch the tray or the router).
- Scenarios: (i) A → signed out → B: a tap on A's stale tray entry, or an https link opened
  while signed out, is buffered and navigated inside B's session when B's MAIN mounts;
  (ii) observed A → signed out → A: same, replayed into A's new login generation, which the
  A1/A2 model forbids for every other late effect; (iii) A signed in, tray holds A's pushes, B
  signs in on the shared device and taps one: A's route (frozen at receive time, §1.1) opens in
  B's session. Data stays protected by RLS; the failure is wrong navigation, stale-intent
  execution for id-less routes (`home`, `profile`, `profile/kyc`, `engineer/amc_visits`), and a
  confusing "Couldn't load" for id routes.
- Reproduction (JVM, deterministic): construct `DeepLinkRouter`, `dispatch` an intent while
  `FakeAuthRepository` is `SignedOut`, then `setSession(SignedIn(B))`, create `DeepLinkHost`
  and collect `events` → the event is delivered today. Device: sign in as A, receive a push,
  sign out, sign in as B, tap the tray entry.
- Fix: (1) stamp every router event with the `SessionOwner` current at dispatch (or `null`
  when no owner is admitted); (2) `DeepLinkHost` (or the root) drops events whose owner is not
  the current MAIN owner and clears the router buffer on `SignedOut`/owner change; (3) the FCM
  intent carries the recipient `user_id` and dispatch drops mismatches (fail closed; this is not
  authorization, only de-duplication of identities); (4) `SignOutCleanup` cancels all posted
  notifications for the device (local, best-effort) and clears the router; (5) product decision
  to record: whether a link that arrives while signed out should be remembered until the same
  process signs in (default proposed here: drop and show the default landing).
- Owner: coordinator (A3); (5) is an owner decision. Tests: T-A3-02, T-A3-05.

### A3-03 · MED · Process restore re-dispatches the launch intent

- Evidence: `MainActivity.onCreate` L63 dispatches on every creation; `onNewIntent` L105
  `setIntent(intent)` makes the last deep link the recreation intent. After process death the
  restored activity dispatches the same route again over the restored NavHost state (double
  navigation, a second copy of a job detail on the back stack, or a re-run of a `home`
  sheet opener). Robolectric `ActivityScenario.recreate()` will show two router events for one
  intent.
- Fix: dispatch only when `savedInstanceState == null`; after a successful dispatch strip the
  extra from the stored intent (`intent.removeExtra(EXTRA_ROUTE)`), and do the same for
  `intent.data` handled routes.
- Owner: coordinator. Tests: T-A3-03.

### A3-04 · MED · Route resolution happens at receive time, not at tap time

- Evidence: `EquipSevaMessagingService` L85-90. The tray entry freezes a route under the
  account signed in when the push arrived; taps happen later, possibly under another account
  (A3-02 iii) or after the row's status changed. Also `resolveNotifyId` L223-234 compares
  `kind == "chat_message"` while the emitted kind is `chat_message_new` (L167), so chat pushes
  never collapse per conversation and every message adds another tray entry carrying a route;
  `ResolveNotifyIdTest` pins the dead literal.
- Fix: carry `(kind, id fields, user_id)` and resolve on dispatch with the current owner;
  use `NotificationDeepLink.KIND_CHAT_MESSAGE_NEW` for the collapse key (keep the legacy literal
  as an alias). Owner: coordinator; the GPT helper's parser tests may pin the collapse key.
  Tests: T-A3-04, T-A3-06.

### A3-05 · LOW (design) · `lastScreen` restore is a device-global, unowned pin — and currently dead

- Evidence: `MainNavGraph` L196-215 navigates `pinned` for whichever owner mounts MAIN.
  The only production writers are `KycViewModel` L76/L80 (`markEntered`/`markExited`, which
  have **no callers**), L96 (`GlobalScope.launch { setLastScreen(null) }` in `onCleared`),
  `DeepLinkHost.consumeLastScreen` L89 and `SignOutCleanup` L61 (best-effort). Nothing ever
  sets the pin today, so the restore path cannot fire; the design is still unsafe the moment a
  caller is added: A → B with a failed or late clear would restore B into A's pinned screen.
- Fix: either delete the pin machinery or, when re-enabled, store `owner:route` (userId +
  login generation), write and clear it through the root-owned writer, and ignore pins whose
  owner is not current.
- Owner: coordinator (overlaps A4; see the A4/A12 report, A4-08). Tests: T-A3-07.

### A3-06 · LOW · Founder destinations are reachable by push without a founder check

- Evidence: `NotificationDeepLink` L100-102 maps the three `admin_*` kinds to founder queues;
  the inbox path (`NotificationsScreen` L178-180 → `MainNavGraph` L680) navigates without
  `isFounder()`. Rows with these kinds are inserted only for admin user ids by the server
  (`…round3782…sql` L166-182 `v_admin_user` loop), so a non-founder should never hold one;
  the client still has no guard, and via A3-01 the route is reachable by anyone.
- Fix: gate `Routes.FOUNDER_*` destinations in `MainNavGraph` on the validated founder flag
  (already available to `HomeHubViewModel` via `Profile.isFounder()`), and map admin kinds to
  `notifications` for non-founders. Owner: coordinator. Tests: T-A3-01 rows F1–F3.

### A3-07 · LOW · Hardcoded copy on deep-link failure paths

- Evidence: `MainNavGraph` L1248 `"Couldn't open that link"`; `DeepLinkHost` KDoc L25-33 and
  L92-99 describe verification that does not exist. Localisation and documentation only.
- Fix: string resource; rewrite the KDoc when the policy in §3 lands. Owner: coordinator.

## 3. Proposed allow/deny contract

Sources: **S1** own `PendingIntent` from the FCM service; **S2** verified https App Link;
**S3** explicit external intent carrying `EXTRA_ROUTE` (indistinguishable from S1 by the
receiver; the policy must therefore be identical for S1 and S3); **S4** custom scheme (none
registered, deny by absence, keep it that way); **S5** in-app inbox tap (authenticated UI);
**S6** `lastScreen` restore; **S7** activity recreation.

Session states: `NONE` (signed out, Loading, Pending, Role, Onboarding) and `MAIN(U)` (owner U
admitted).

| Route class | Shape rule | S1/S3 | S2 | S5 | S6 | S7 |
| --- | --- | --- | --- | --- | --- | --- |
| job `repair/detail/{id}` | `RPR-\d{1,8}` or UUID, no `%`, `/`, `?`, `#`, whitespace after the prefix | MAIN(U) and payload `user_id == U`: allow; NONE: drop | MAIN(U): allow (server authorises); NONE: drop (open question O1) | allow | n/a | never re-dispatch |
| chat `chat/detail/{uuid}` | UUID | same as job | same | allow | n/a | never |
| engineer `engineers/public/{uuid}` | UUID | same | same | allow | n/a | never |
| directory `engineers/directory`, inbox `notifications` | exact | same | same | allow | n/a | never |
| kyc `profile/kyc`, home, profile, `engineer/amc_visits`, `amc/contract/{uuid}` | exact / UUID | MAIN(U) with `user_id == U`: allow; NONE: drop | deny (not App-Link paths today) | allow | kyc only, owner-matched | never |
| founder `founder/*` | any | **deny** | **deny** | allow only when `isFounder()` | deny | never |
| root/auth/onboarding (`root_*`, `auth*`, `hospital/phone_onboarding`, `*/onboarding`) | any | **deny** | deny | deny | deny | never |
| anything else (encoded ids, query strings not in the table, unknown prefixes) | — | **deny + log** | deny | deny | deny | never |
| A → B, A → SignedOut → A | — | events created under a previous owner/generation are discarded when the owner changes; router buffer cleared on `SignedOut` | same | n/a (UI is per login since A2) | pin must carry the owner | — |
| cold start | — | at most one pending event, delivered only after MAIN admits an owner and `user_id` matches; otherwise dropped | same | — | — | dispatch only when `savedInstanceState == null` |

Rules that make the table safe:

1. **Identical policy for S1 and S3.** Never branch on an "origin" extra; it is forgeable.
2. **The parser is the allow-list.** Reuse `NotificationDeepLink.routeFor` /
   `DeepLinkRouter.routeForParts` shapes for every external input; do not add a second table.
3. **Deny is silent for the user but logged** (breadcrumb via `CrashReporter`, no PII).
4. **The client allow-list is not authorization.** Every destination keeps its server checks:
   repair job/bids/evidence RLS (hospital org member or assigned engineer), chat participant
   RLS, `engineer_public_profile` verified-only RPC, AMC contract party RLS, `is_founder()` on
   every founder RPC, self-only profile/KYC rows. Server review items: (a) each inserting
   function must derive `data.*` ids only from rows the recipient is a party to; (b)
   `send_push_notification` should copy only whitelisted keys (`kind`, the id fields above,
   `user_id`, `channel`, `category`) into FCM data; (c) the recipient `user_id` must be present
   in FCM data for the client owner match. None of (a)–(c) is proven in this pass.

Open question **O1** (owner decision): remember a link that arrived while signed out and
open it after the same process signs in, or drop it? Proposed default: drop.

## 4. Test-first plan

Naming avoids the GPT helper's files (`DeepLinkHostEngineerStatusTest`,
`NotificationDeepLinkEdgeCasesTest`). All JVM tests are Robolectric SDK 34 with plain
`Application` where an `Intent`/`Uri` is needed, otherwise pure JUnit. Each row lists the
stimulus, today's observable result (to pin first as a characterisation test if useful), and
the target after the fix.

| ID | Test class (new) | Stimulus | Today | Target |
| --- | --- | --- | --- | --- |
| T-A3-01 | `navigation/DeepLinkRouterPolicyTest` | `Intent().putExtra(EXTRA_ROUTE, r)` for r in {`founder/dashboard`, `founder/integrity?user=…&name=x`, `root_main/x/engineer`, `hospital/phone_onboarding`, `repair/detail/RPR-00027`, `repair/detail/RPR-00027?x=1`, `repair/detail/%2E%2E`, `chat/detail/{uuid}`, `chat/detail/not-a-uuid`, `notifications`, `""`, `"   "`} | all non-blank forwarded verbatim | only job/chat/engineer/directory/inbox shapes forwarded; founder/root/onboarding/malformed dropped; blank falls back to `intent.data` |
| T-A3-01b | same | `intent.data` = `https://equipseva.com/job/RPR-1`, `https://evil.com/job/RPR-1`, `http://equipseva.com/job/RPR-1`, `equipseva://job/RPR-1`, `https://equipseva.com/job/RPR-000000001` (9 digits) | matches `DeepLinkRouterTest` | unchanged (regression guard for legitimate taps) |
| T-A3-02 | `navigation/DeepLinkHostOwnerGateTest` | dispatch while `FakeAuthRepository` is `SignedOut`; then `SignedIn(B)`; construct host; collect | delivered | dropped; buffer empty |
| T-A3-02b | same | `SignedIn(A)` + event with `user_id=A` buffered; `SignedOut`; `SignedIn(A)` (new generation); collect | delivered | dropped (generation changed) |
| T-A3-02c | same | `SignedIn(A)`; two events before any collector; collect | both, in order | both, in order (legitimate cold-start tap preserved) |
| T-A3-03 | `MainActivityDeepLinkDispatchTest` (`ActivityScenario`, Hilt test rule or a fake router bound via `@BindValue`) | launch with `EXTRA_ROUTE`; `recreate()`; `onNewIntent` | 2 events after recreate | 1 after recreate; +1 after `onNewIntent`; extra stripped from `activity.intent` |
| T-A3-04 | `core/push/ResolveNotifyIdChatNewTest` | `resolveNotifyId("chat_message_new", {conversation_id}, msgId)` | falls back to `messageId` | collapses on the conversation |
| T-A3-05 | `core/auth/SignOutCleanupTrayTest` | wipe → verify `NotificationManagerCompat.cancelAll()` and `DeepLinkRouter.clear()` called (fakes) | absent | called, best-effort, before network steps |
| T-A3-06 | `core/push/PushLaunchIntentContractTest` | pure builder extracted from the service: `(kind, data, recipient)` → extras | n/a (route only) | extras = `{kind, id fields, user_id}`, no `EXTRA_ROUTE`; `routeFor` on those extras reproduces the 34-kind table |
| T-A3-07 | `navigation/LastScreenOwnerTest` | pin written under A; MAIN mounts for B | B navigates to A's pin | ignored; pin cleared on the sign-out generation |
| T-A3-08 | `supabase/tests/push_data_whitelist.test.mjs` (Node/PGlite suite) | call the inserting functions for each kind with fixtures; inspect `notifications.data` keys and the edge-function data mapping | not verified | keys ⊆ {kind, repair_job_id, conversation_id, engineer_id, amc_contract_id, user_id, channel, category, title, body}; recipient is a party to every referenced row |

Minimal integration points (production, coordinator-owned, none touched here):

1. `DeepLinkRouter.dispatch` → delegate to a pure `DeepLinkPolicy.resolve(intent, ownerNow)`
   returning `DeepLinkTarget(route, ownerAtDispatch, recipientUid?)`; add `clear()`.
2. `DeepLinkHost` → collect the root `SessionPresentation` (or `AuthRepository.sessionState`)
   and gate/clear; the KDoc already promises this.
3. `MainActivity.onCreate` → `if (savedInstanceState == null) dispatch(intent)`; strip
   consumed extras.
4. `EquipSevaMessagingService` → extras = kind + ids + recipient; no pre-resolved route.
5. `SignOutCleanup` → cancel tray notifications and clear the router (local, best-effort,
   before network steps), keeping the existing draft/outbox fences first.
6. `MainNavGraph` founder destinations → `isFounder` guard; deep-link sink keeps `runCatching`.

## 5. What was not proven

- No device execution; the adb reproductions in A3-01 are written, not run.
- Third-party delivery of `EXTRA_ROUTE` is proven at the router level (any explicit intent
  reaches `dispatch`), not exercised end to end on a device.
- Edge-function data whitelist and per-function recipient derivation (§1.3) were not
  reviewed line by line.
- Whether any client-side cache would show account A's job data to B after a replayed route
  (repair detail appears to read from the network; not verified).

## 6. Ownership and merge notes

All fixes are coordinator-owned (A3). The GPT helper's A10 change to `DeepLinkHost` touches
the same file as integration point 2; sequence A10 first, then add the owner gate. This report
adds no code and can be merged into the Codex branch as documentation at any time.

## 7. Reviewed files (SHA-256, git blob, lines)

```text
9503e99098157b7c3b5ad8c3cac1da9ac998a3fbf5e9ee3b58d6443c8dc9b569  a8d6bbce  141   app/src/main/AndroidManifest.xml
e6f60913f7078b581432c5d33128f2db4db1b1087da892a9fff718f44938cecc  674db01b  140   app/src/main/kotlin/com/equipseva/app/MainActivity.kt
b68308a41e8f180d9607928634249a963546d786cbd8b79f696a87fb50a1ba5f  1a4e5127  95    app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkRouter.kt
2895882d81fc3abe98ad3a4206eecce49fd6d650d9067b41a1d7cd6e4dc33f54  dcc5198b  120   app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkHost.kt
227759b095d141cd3f7b548c042056da6104533a8eabbf67044e5f9d08562272  9c9c542a  228   app/src/main/kotlin/com/equipseva/app/navigation/NotificationDeepLink.kt
eb241e4fb8ee2afe6fcd8e9b8d374da6aaf88ade9b78cc5c2c65ac93a3ba1448  c36e3a8b  234   app/src/main/kotlin/com/equipseva/app/core/push/EquipSevaMessagingService.kt
97c4626a27e138a1de94acc99b4a2ab8fd95508c0bb38b343c213a08620dbb7b  f8560173  1302  app/src/main/kotlin/com/equipseva/app/navigation/MainNavGraph.kt (L160-262, L673-690, L1235-1302 read)
20425e0b194c8e2be3aced198c307ece6d7af84db12559929b50a95efb9b1568  d40afe4b  485   app/src/main/kotlin/com/equipseva/app/features/notifications/NotificationsScreen.kt (L63-190 read)
3be2f9f269ebeae662a9946089fe7810f67814b50c14b93c6e70f575420718b9  1afced93  194   app/src/main/kotlin/com/equipseva/app/navigation/RootSessionHost.kt
1a587bd7a6a55e8bad3fd11f4852f164fdfd837e573a22b287ac937807e7114e  1f6d8a19  168   app/src/main/kotlin/com/equipseva/app/navigation/AppNavGraph.kt
```

Server files read in part: `supabase/migrations/20260425020000_notifications_push_dispatch_trigger.sql`
(L40-100), `20260424104624_round4_close_remaining_with_check_gaps.sql` (L60-78),
`20260428320000_security_revoke_delete_grants.sql` (L24), `20263871000000_round3782_…sql`
(L141-182), `supabase/functions/send_push_notification/index.ts` (grep only).
