# Handoff — Claude independent review, 11 September 2026

Branch `claudedev-next-review-20260911`, isolated worktree
`C:/Users/lokes/equipseva-review-20260911`, cut from
`origin/codex/security-foundation-20260907` at
**base `1e770076358e74f6f40a99a4907f831da59e791c`** (the September 11 A2 WIP save
checkpoint, newer than `64107db7`). Head SHA: recorded in §6 after the commit. Documentation
only: no production code, fixture, test, build file, migration, secret or deployment was
touched; no Gradle run, device, notification, job, bid or credential was used.

## 1. What was delivered

| File | Content |
| --- | --- |
| `docs/helper-reviews/claude-20260911/A3_deep_link_security_contract.md` | trace of `MainActivity`, `DeepLinkRouter`, `NotificationDeepLink`, `DeepLinkHost`, FCM service, MainNavGraph sinks; 34-kind route inventory; 7 findings; allow/deny table; server validation list; test-first plan with stimuli and integration points |
| `docs/helper-reviews/claude-20260911/A4_A12_mutation_ownership_audit.md` | writer/reader inventory of device-global state; 11 findings with file:line evidence; owned write-boundary proposal; deterministic barrier tests; A8 profile-read fallback recommendation (separate section) |
| `docs/helper-reviews/claude-20260911/UX_login_both_roles_plan.md` | action-level maps of login/role/setup/account switching, hospital and engineer journeys (prereq, pending, error/offline, cancel, restart, next); eight prioritised slices; large-text, TalkBack, EN/HI/TE and dark-theme checks; owner decisions |
| `docs/helper-reviews/claude-20260911/QA_matrix.md` | acceptance cases by evidence class (unit / Compose / API / device / human), status and prerequisites; disposition without numeric scores |
| `docs/HANDOFF_CLAUDE_NEXT_REVIEW.md` | this file |

## 2. Status reconciliation with A2 (read before assigning work)

A2 at this base already closes the earlier audit's F2 (NeedsRole now mounts the supported-role
chooser; unknown roles get no tabs), F3 (login generations), F7 (atomic gate), F10 (sign-up
"Sign in" link) and demotes the legacy phone-onboarding route. Those recommendations are not
repeated. The A2 dark-theme contrast blocker stays with the coordinator. Files traced for A3
and the unowned writers audited for A4/A12 were **not** changed by A1 or A2, so every finding
there is pre-existing; the two A2-introduced surfaces noted (gate sign-out ordering and copy,
A4-11) are not regressions.

## 3. Findings that block a passing disposition (details in the reports)

| ID | Sev | One line |
| --- | --- | --- |
| A3-01 | HIGH | `EXTRA_ROUTE` from any explicit intent to the exported activity is navigated verbatim, including `founder/*` UI and parameterised routes; an "FCM-origin" extra cannot make this safe |
| A3-02 | HIGH | Singleton buffered router, per-login host, no session gating and no tray cancellation replay deep links across A → B and A → SignedOut → A |
| A4-01 | HIGH | `SignOutCleanup` is global and swallows cancellation; a cleanup stalled on the token revoke wipes the next login's outbox, photo stash, pending-payment markers and settings |
| A4-02 | HIGH | `DeviceTokenRegistrar.revoke()` reads the live user; a late revoke deletes the next user's device-token row |
| A3-03, A3-04, A4-03…A4-07, A8 | MED | restore re-dispatch; receive-time route freezing; two sign-out paths with wipe-before-signOut; unowned mirror writes in SignUp/Profile and mirror readers in HomeHub/RepairJobDetail; profile fallback synthesises or nulls on ambiguous reads |
| UX | — | mandatory setup screens without an exit, no in-flight indicators on the auth graph, fixed-height controls, 47 untranslated auth keys and 32 Kotlin literals, light tokens on a dark scheme |

## 4. What was actually reviewed, and what was not

Read line by line at the recorded hashes: manifest, `MainActivity`, `DeepLinkRouter`,
`DeepLinkHost`, `NotificationDeepLink`, `EquipSevaMessagingService`, `RootSessionHost`,
`AppNavGraph`, `AuthNavGraph`, `SessionViewModel`, `SessionPresentation`,
`RoleSelectViewModel`, `RoleSelectScreen`, `SignUpViewModel`, `SignOutCleanup`,
`DeviceTokenRegistrar`, `ProfileInvalidations`, the A2 diffs of `MainNavGraph`,
`HomeHubScreen`, `SignUpScreen`, `SupabaseProfileRepository`; regions of `MainNavGraph`,
`NotificationsScreen`, `ProfileViewModel`, `UserPrefs`, `SecurePrefs`,
`SupabaseAuthRepository`, `SupabaseProfileRepository`, `HomeHubViewModel`, `KycViewModel`,
`RequestServiceDraftStore`, `EngineerPayoutOnboardingScreen`, `RepairJobDetailViewModel`
(viewer-role resolution); the notification dispatch trigger, the round-4 update policy, the
delete-grant revoke, one inserting function, and greps of the push edge function. The Codex
route inventory, A2 handoff, QA contract, critic and QA reviews were read for reconciliation.

Produced by static exploration passes and only spot-checked (marked "expl." in the UX plan):
the hospital and engineer journey screens beyond the files above. Not reviewed: web/, the
edge function bodies in full, migration chain semantics, `KycScreen` in full. Nothing was
executed, rendered or run on a device by this review; the QA matrix marks every such case
unassessed. No score is claimed for the app, for auth as a whole, or for A2.

## 5. Unresolved questions for the owner

1. Deep link received while signed out: drop (proposed default) or remember for the same
   process (A3, O1).
2. Repeat-booking semantics, Google-only re-authentication, single phone-collection point,
   in-app email-confirmation return path, payout readiness on a failed readiness RPC (UX plan
   §6).
3. Whether `lastScreen` restore should be removed or re-enabled owner-keyed (A3-05/A4-08; it is
   dead code today).
4. Sequencing with the GPT-5.3 helper: its A10 change to `DeepLinkHost.engineerStatus` touches
   the same file as the proposed owner gate (A3 integration point 2); land A10 first.

## 6. Merge instructions

- The branch contains only the five documentation files above; no conflict with A2 source,
  tests or resources is possible. Merge or cherry-pick into
  `codex/security-foundation-20260907` at the coordinator's convenience (`git fetch origin
  claudedev-next-review-20260911 && git merge --no-ff origin/claudedev-next-review-20260911`).
- Do not merge to `main`; do not treat any recommendation as an instruction to restore old
  behaviour. Implement test-first per the plans, then request independent critic/QA review.
- Head SHA and push confirmation: see the "Commit record" at the end of this file.

## 7. Commit record

Filled in by the final docs commit on this branch.
