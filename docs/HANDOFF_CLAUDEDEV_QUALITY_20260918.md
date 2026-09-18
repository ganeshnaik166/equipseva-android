# Handoff — `claudedev-quality-20260912` (full code-quality audit + fixes), 2026-09-18

Supersedes `HANDOFF_CLAUDEDEV_QUALITY_20260912.md`. Branch `claudedev-quality-20260912`,
worktree `C:/Users/lokes/equipseva-quality-20260912`.

## State
- Rebased onto `origin/codex/auth-integration-20260911` @ **`9a0ecf89`** (the Codex coordinator's integration
  tip; its `DeepLinkPolicy` + router guard commit `e58c48c2` and A10 fix `e22c7c5b` are underneath us —
  my own m1 `DeepLinkPolicy` was the same file and was dropped as an already-applied cherry-pick).
- Tip **`9d36092d`**, pushed. Tree clean.
- Verify bar on the tip: `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug` → lint + assemble green,
  **3,263 tests run / 7 failed**. All seven are `features.kyc.KycEmailOtpStateTest` cancellation cases, which
  the coordinator's own `HANDOFF_ANDROID_UI_2026-09-13_OTP_WIP.md` records as failing/unrun; the identical
  seven fail on the untouched base `9a0ecf89`. Nothing on this branch touches KYC OTP.
- A fresh worktree needs `local.properties` + `app/google-services.json` copied in, or
  `processDebugGoogleServices` fails.

## The audit (this is the deliverable — read it before writing code)
Seven read-only scopes ran against a frozen snapshot worktree of `9a0ecf89`
(`C:/Users/lokes/equipseva-audit-snap`), each reading every file in its scope and cross-checking SQL
contracts in `supabase/migrations`. Reports are committed verbatim under **`docs/audit-20260917/`**:

| report | scope | findings |
|---|---|---|
| `auth-nav.md` | core/auth, features/auth, navigation, core/push, MainActivity, onboarding | AN-01..17 |
| `data-sql.md` | core/data (80 files), network, supabase, storage — DTO↔SQL contracts | DS-01..12 |
| `repair-hospital.md` | features/repair, hospital, mybids, activework, chat | RH-01..22 |
| `money-kyc-profile.md` | features/amc, earnings, payouts, core/payments, kyc, profile, engineer | F01..F24 |
| `sync-security-build.md` | core/sync, security, observability, util, location, Gradle, manifest, CI | SSB-01..22 |
| `compose-ui.md` | designsystem, features/home, notifications, founder, about, locale strings | C01..C27 |
| `sql-edge.md` | 10 newest migrations, all edge functions, cron/payout workflows, r3821 client contract | SE-01..13 |
| `backend-digest.md` | house style + rules digest (AGENTS_READ_FIRST, CONTRIBUTING, migration idioms) | reference |

Each entry carries file:line, the evidence, a minimal fix and the test that would pin it. Every finding was
put through two adversarial skeptics (correctness lens + reproduce/impact lens) before landing in a report;
the reports also list what each auditor read and found clean.

## What is FIXED on this branch
**m2 `fdd00848`** — deep-link ownership and sign-out ordering (A3-02/A3-03, A4-01/A4-02):
`DeepLinkRouter` observes auth and stamps every event with the dispatching owner; links dispatched while
`Unknown` queue in order and are stamped by the first `SignedIn`; links dispatched while `SignedOut` are
dropped; `SignedOut` clears queue + buffer; a recipient `user_id` mismatch drops the event. `DeepLinkHost`
forwards only events stamped for the live owner. `MainActivity` dispatches only when
`savedInstanceState == null`. `SignOutCleanup` gained `bestEffort{}` (rethrows `CancellationException`) and a
two-phase order: draft fence → `captureRevocation()` → router clear → tray `cancelAll` → all local wipes →
`revoke(capture)` last. `DeviceTokenRegistrar` gained `Revocation`/`captureRevocation()`/`revoke(capture)`.
Tests: `DeepLinkRouterOwnerGateTest` (8), `DeepLinkHostOwnerGateTest` (2), `SignOutCleanupOwnershipTest` (4).

**m3 `9d36092d`** — twelve core-layer findings: DS-01 (offset timestamps unparseable on Android 8-13 →
`OffsetDateTime` with an `Instant` fallback), AN-03 (`RefreshFailure` → `Unknown`, not `SignedOut`), AN-06
(new `ProviderReauthRequiredException` for password-less accounts), AN-07 (email OTP refuses a foreign
address, `createUser = false`, fails closed if the imported session switches user), DS-07 (42501 no longer
blanket KYC copy, raw denial never echoed), AN-12 (chat collapse literal), AN-10 (`onNewToken` completes
inline), AN-02 (background-tap fallback: re-run the mapper over intent extras through the same allow-list),
AN-11 (no decode exception object in the session log), DS-06 (nullable `job_number`), DS-09 (validator
ceilings match the bucket limits), DS-12 (block-cache refresh under the mutex), DS-11 (client-side CHECK
mirror on cost revisions), DS-08 (search sanitiser neutralises the PostgREST `or=()` delimiters).

## What is NOT fixed (the remaining work, in priority order)
Four implementation batches were dispatched and killed by an interrupt before writing anything, so the
feature layer is untouched. Priority order, with the reason:

1. **SSB-01/02/03/06/07/09/13 (outbox)** — duplicate chat sends from two concurrent drains,
   `REPLACE` cancelling an in-flight drain, cold-start "no session" burning the 5-attempt budget and
   poison-dropping queued writes, 401 treated as permanent, stash files leaking KYC bytes, swallowed
   cancellation skipping the §65B evidence registration. Highest blast radius: silent data loss.
2. **SE-01/02/03/07 (backend money paths)** — round3822's function-level `statement_timeout` cannot extend
   an in-flight RPC statement (the daily snapshot slot was green on 2026-09-17, so verify before acting),
   `record_engineer_payout_dispatch` rejects the `'queued'` status the worker sends, requeue nulls the
   reference id, payouts-webhook mixes Cashfree V1 body with V2 signature.
3. **RH-01/RH-03/RH-17** — every status/bid/chat failure treated as "offline" and queued for an outbox that
   drops 4xx, so the user is told it will send and it never does. Shared helper `isNetworkFailure()`.
4. **F01..F04, F07** — AMC sheet wedged in "Processing…", checkout opened with no listener, no verify retry
   or recovery after a captured payment, KYC `onCleared` deleting documents an in-flight save just persisted.
5. **SSB-05 (public `mapping.txt`)**, SSB-12/SE-06 (response bodies in public Actions logs), SSB-10
   (`<queries>` missing so the RE detector is dead), SSB-19 (branch filters exclude active branches).
6. **C01..C10 + C16..C18** — fixed heights clipping large text, sub-48dp targets, the swipe-dismiss modal
   that swallows all taps, permission banner not re-evaluated on resume.
7. **SE-04/05/08/10** — `finalize_repair_photo` has no caller, Play Integrity nonce unverified (replayable),
   `submit_dsr` can replace a countersigned report.
8. Report-only / owner decisions: C12 (709/765 hi+te strings are English), C13/C14/F18/RH-19 (hard-coded
   copy), AN-05/AN-09, F19, SSB-15, SSB-20.

## Prod facts verified read-only during the audit (2026-09-17)
- `cron_tick_runs` id 145, 2026-09-17 08:28 UTC: **daily slot green** (`ok: true`, no failed slots) after
  round3822 — the four prior days were red on `db-storage-snapshot`. SE-01's reasoning about the timeout
  scope may therefore be wrong in practice; re-measure before changing anything.
- 4,876 public tables, 19,363 public functions (19,315 SECURITY DEFINER, 0 without a pinned `search_path`),
  3,515 policies, **0 public tables with RLS off**.
- 542 functions executable by `anon` (231 via a PUBLIC grant), of which 195 are `founder_*`; 193 of those
  have an internal `is_founder()`/`is_admin()` gate, **2 do not** (`founder_clv_snapshot_all_hospitals`,
  `founder_okr_v2_freq_threshold`) — worth a look, they may be pure-math helpers.
- `plpgsql_check` and `pgtap` are available but not installed; `pgcrypto`/`pg_trgm` live in `extensions`.
- Role budgets: `authenticator` and `authenticated` `statement_timeout=8s` (+ `lock_timeout=8s` on the
  former), `anon` 3s.
- `device_tokens`: `authenticated` has INSERT but **not DELETE**, and there is no `*device_token*` RPC —
  which is AN-01's evidence that both client DELETE paths are dead (they swallow the 42501).
- `finalize_repair_photo` does **not** exist in prod (round3823 unapplied); `register_evidence`'s live body
  md5 is `eb3a7c50…`, i.e. not the round3821 version either.

## Rules followed
Additive/behaviour-preserving apart from the defect; comments explain WHY and never name rounds or tasks;
non-trivial gates lifted to `internal fun` and pinned; one commit per milestone with the reasoning in the
body; only this branch pushed. The Gradle slot file
(`C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-build-slot.md`) was taken over on
2026-09-16 after its previous holder had left no Gradle process for three days; release it (write `FREE`)
when the next verification run finishes.

## Resume checklist
1. `git fetch`; rebase onto the coordinator's tip if it moved (it owns RoleSelect colours, the
   `engineerStatus` section of `DeepLinkHost`, and the KYC email-OTP slice — do not edit those).
2. Pick a batch from the priority list, read its report entries, implement with tests, run the full bar,
   commit with the WHY in the body, push.
3. The 7 `KycEmailOtpStateTest` failures are the coordinator's; do not try to fix them and do not count them
   as yours.
