# Scheduled-job coverage gap (found 2026-09-03, round3794)

**Status: real, currently harmless, becomes live at launch. Needs a
go/no-go from the founder, not a code cleanup.**

## Summary

The migrations declare **31 distinct scheduled jobs**. **11 actually have
a scheduler. 20 have none at all.** Nothing failed loudly, because every
`cron.schedule(...)` call site is either guarded on
`extname = 'pg_cron'` or wrapped in `EXCEPTION WHEN OTHERS THEN RAISE
NOTICE`, so the entire set failed silently at migration time.

**19 of those 20 already have their RPC in production**, so for almost
all of them this is a wiring job, not development work. The single
exception is `founder_invoice_digest_daily`, whose target is an edge
function that nothing invokes.

## Why nothing is scheduled via pg_cron

`pg_cron` **is not installed on this project** — there is no `cron`
schema at all. Installed extensions are only: `pg_net`,
`pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql`, `plpgsql_check`,
`supabase_vault`, `uuid-ossp`.

That is **deliberate**, not an accident. There is a documented Free-tier
substitute (`cron-tick-hourly.yml` calls it "v2.1 PR-D39"):

```
GitHub Actions (schedule:)  ->  POST /functions/v1/cron-tick?slot=<slot>  ->  admin.rpc(...)
```

Verified working as designed:

- `.github/workflows/cron-tick-hourly.yml`, `cron-tick-daily.yml`,
  `engineer-payouts-worker.yml`, `supabase-keepalive.yml` all exist on
  `origin/main` **with their `schedule:` triggers intact**. This matters
  because GitHub only runs scheduled workflows from the **default
  branch** — so the round3768 finding (workflows never triggering on
  `ops/**`) does NOT apply to these; `push:` triggers and `schedule:`
  triggers are independent.
- The founder console already surfaces the state: `/cron-status` calls
  `founder_cron_status()` and renders "pg_cron not enabled on this
  database … the platform team can flip pg_cron on".

So the substitute is correctly wired. **The gap is that it only covers a
third of the declared jobs.**

## The 11 jobs that DO run (via `cron-tick`)

| job | RPC |
|---|---|
| repair-job-escrow-auto-release | `process_due_repair_job_escrow_releases` |
| expire-stale-cost-revisions | `expire_stale_cost_revisions` |
| amc-auto-create-visits / amc-create-due-visits | `auto_create_due_amc_visits` |
| amc-auto-renew / amc-auto-renew-expiring | `auto_renew_expiring_amc_contracts` |
| purge-old-notifications | `purge_old_notifications` |
| purge-old-content-reports | `purge_old_content_reports` |
| purge-old-device-integrity-checks | `purge_old_device_integrity_checks` |
| purge-old-virtual-call-sessions | `purge_old_virtual_call_sessions` |
| purge-old-phone-otp-requests | `purge_old_phone_otp_requests` |

`cron-tick` additionally runs 4 sweeps that were never declared as
pg_cron jobs (`requeue_stuck_engineer_payouts`,
`sweep_amc_sla_unresponded_visits`, `notify_expiring_amc_contracts`,
`expire_lapsed_amc_contracts`, `purge_old_spot_audit_invitations`,
`purge_old_chat_moderation_events`).

## The 20 with NO scheduler

**Every one of these has its RPC present in production. The gap is the
SCHEDULER, not the implementation — wiring each into a `cron-tick` slot
is the whole fix (19):**

| job | schedule | RPC | why it matters |
|---|---|---|---|
| `sweep_timed_out_code_reds_every_5min` | `*/5 * * * *` | `sweep_timed_out_code_reds` | Code Red safety escalation never times out |
| `reap_expired_refund_authorizations_hourly` | hourly | `reap_expired_refund_authorizations` | money |
| `reap_stranded_pending_payment_amc_contracts` | hourly | same name | contracts stuck `pending_payment` |
| `run_daily_reconciliation_at_0130_ist` | daily | `run_daily_reconciliation` | payment reconciliation |
| `reap_stranded_requested_repair_jobs` | daily | same name | flagged in-console as "r479 audit-8 HIGH" |
| `schedule_engineer_kyc_renewals_daily` | daily | `schedule_engineer_kyc_renewals` | backs the round3770 KYC Renewal screen |
| `reap_expired_kyc_renewals_daily` | daily | `reap_expired_kyc_renewals` | same |
| `evaluate_all_pending_referrals_daily` | daily | `evaluate_all_pending_referrals` | backs the Referral Bounty screen — bounties never evaluate |
| `refresh_engineer_tier_cache_daily` | daily | `refresh_engineer_tier_cache` | backs the Commission Tier screen |
| `recompute_all_pm_schedules_daily` | daily | `recompute_all_pm_schedules` | backs the Predictive PM Calendar screen |
| `recompute_all_engineer_certifications_daily` | daily | `recompute_all_engineer_certifications` | |
| `run_daily_risk_scoring` | daily | `run_daily_risk_scoring` | fraud |
| `scan_collusion_pairs_daily` | daily | `scan_collusion_pairs` | fraud |
| `scan_duplicate_accounts_daily` | daily | `scan_duplicate_accounts` | fraud |

Plus these five, which are the same "exists but unscheduled" shape:

| job | schedule | RPC | why it matters |
|---|---|---|---|
| `analytics_events_retention_sweep` | daily | same name | DPDP data-retention |
| `investor_share_view_log_retention_sweep` | daily | same name | DPDP data-retention |
| `nabh_export_audit_retention_sweep` | daily | same name | DPDP data-retention |
| `db_storage_snapshot_sweep` | daily | same name | why `founder_db_storage_snapshots_summary` has no snapshot to report |
| `recompute_all_engineer_certifications_daily` | daily | `recompute_all_engineer_certifications` | |

> **Correction (same session).** The first version of this document claimed
> these four RPCs did NOT exist and that the three retention purges were
> "DPDP retention obligations with no implementation at all". **That was
> wrong.** The error was mine: when a `cron.schedule()` call's SQL text
> could not be captured by the extractor, I inferred the RPC name from
> the job name and guessed the `purge_old_*` convention used by the
> already-scheduled purges. In fact these four are named *identically to
> their job*, and all four are present in production:
> `analytics_events_retention_sweep()`,
> `investor_share_view_log_retention_sweep()`,
> `nabh_export_audit_retention_sweep()`, `db_storage_snapshot_sweep()`.
> So the DPDP retention sweeps ARE implemented — they simply never run.
> That is a materially smaller problem (wiring, not development) and it is
> corrected here rather than left to mislead. Lesson: do not infer an
> object's name from a naming convention when you can ask the catalog.

**The one genuine non-RPC:** `founder_invoice_digest_daily`. There IS a
`founder_invoice_digest` **edge function**, so it correctly has no
`pg_proc` entry — but no workflow invokes it, so the daily invoice digest
never sends.

**One wiring detail:** `run_daily_reconciliation` takes `p_date date`
(all the others are zero-arg), so a slot for it must pass a date —
presumably `current_date - 1` to reconcile the completed day.

## Blast radius — measured, and this is why it is not urgent yet

| table | rows |
|---|---|
| `repair_jobs` | 39 total, 26 in `requested` |
| `repair_job_escrow` | 6 total, **0 held** |
| `amc_contracts` | 3 |
| `notifications` | 54 |
| `equipment_pm_schedule` | **0** |
| `dsr_reports` | **0** |

So: the escrow auto-release job never running has **stranded no money**
(0 held). Nothing has silently accumulated at scale, because the platform
is pre-launch. **Enabling all 14 at once today is low-risk precisely
because there is almost no data** — which makes now the cheapest possible
time to do it, and launch the worst.

Two of these are ALSO empty for an unrelated reason and will stay empty
even once scheduled: `recompute_all_pm_schedules` projects from signed
DSRs and `dsr_reports` has 0 rows (there is no DSR-submission path in the
app — same root cause as the round3786 `evidence_ledger` finding).

## Recommendation

1. **Add the 14 existing RPCs as `cron-tick` slots** and put them in the
   `hourly` / `daily` groups matching their declared schedules. Cheap,
   reversible, and the sweeps are idempotent by design.
   `sweep_timed_out_code_reds` wants `*/5`, so it needs its own workflow
   (or accept hourly).
2. **Wire `founder_invoice_digest`** — it is an edge function with no
   caller, so it needs a workflow (or a `cron-tick` slot that invokes it),
   not an RPC slot.
3. **Optionally just enable `pg_cron`** (Supabase dashboard → Database →
   Extensions). Every one of the 31 `cron.schedule` calls is already
   written and guarded, so enabling the extension and re-running those
   migration blocks would register all 31 with no new code. This is the
   smaller change of the two, but it is a platform/tier decision.
4. Do NOT silently enable the DELETE-shaped sweeps against a production
   dataset later without re-measuring the blast radius above.

## How this was found

While repairing the `plpgsql_check` sweep's 42P01 class, four functions
reported `relation "cron.job" does not exist`. Checking whether `cron`
existed at all led to the extension list, then to the 31 declared jobs,
then to the guard/exception wrappers that hid the failures.

Worth noting for calibration: those four functions are **plpgsql_check
false positives** in the sense that they do not crash —
`founder_cron_status()` executes and returns 0 rows because it guards on
extension presence. Same shape as the wrapped-42883 false positives
already documented.

---

## RESOLVED (2026-09-05, round3806-3807) — founder-approved

The founder approved options 1+2 together. What shipped:

* **round3806**: `engineers.verification_status_updated_at` added,
  backfilled to `now()` for the 16 verified engineers (NOT `created_at` —
  the mass-expiry hazard documented above), made server-authoritative by a
  stamping trigger on every status change, and guarded against owners
  moving their own renewal clock. `schedule_engineer_kyc_renewals` now
  runs (verified: creates exactly 0 renewals on the fresh backfill) and
  `founder_kyc_pipeline_snapshot_summary` — one of the sweep's nine
  refusals — is repaired.
* **round3807**: 19 new cron-tick slots (18 RPCs + an `invoice-digest`
  slot that server-side-invokes the `founder_invoice_digest` edge function
  with the shared `CRON_TICK_SECRET`). The hourly/daily GROUPS were
  extended, so the existing scheduled workflows on `main` pick everything
  up with **zero default-branch changes**. Deployed; bad-secret probe
  returns 401.
* **Every sweep was dry-run (rolled back) before deploy** — which caught
  one real bug: the job name says `refresh_engineer_tier_cache`, but that
  function takes a uuid (per-engineer); the bulk sweep is
  `refresh_all_engineer_tier_cache()`. The naive wiring would have 42883'd
  on every daily tick.
* **Then every sweep ran live once**, effects verified: stranded-job
  reaper cancelled 25 stale test jobs (requested 26 → 1), first DB storage
  snapshot captured (4,875 relations — the summary page finally has data),
  first daily reconciliation recorded for IST-yesterday in
  `reconciliation_runs`, tier cache populated for all 16 engineers, risk
  scoring wrote 3 scores, duplicate-account scan flagged 16 (expected on a
  seeded test DB — all review accounts share attributes).

Still open, deliberately:

* **Code Red runs HOURLY, not the declared `*/5`.** A 5-minute cadence
  needs a one-line workflow on `main` POSTing `?slot=sweep-code-reds` —
  `main` is frozen, so that is the founder's merge to make.
* The `invoice-digest` slot proves out on the next scheduled daily tick
  (it needs the real `CRON_TICK_SECRET`, which nothing local holds). A
  failure will surface in the workflow email with `error_code: H<status>`.
* Enabling pg_cron proper (option 3) is now moot unless sub-hourly
  scheduling is wanted platform-wide.

---

## FOUND WHILE VERIFYING (2026-09-05, round3809): the payouts worker has been failing every ~3 hours since at least Aug 23 — and its canary was structurally mute

Checked the scheduled workflows via GitHub's public API after the
round3807 deploy. `cron-tick-hourly` and `cron-tick-daily`: green.
`engineer-payouts-worker`: **failure on every one of its last 150+ runs**
(every page of history checked, back to 2026-08-23; in reality since
June — see below).

**Root cause chain, each link verified:**

1. `pick_engineer_payouts_for_processing(25)` returns 1 row — a payout
   **queued since 2026-06-10**: ₹18.60 to
   `test-engineer-e2e@equipseva.local` (an E2E-test account) for
   RPR-00038, with **1,372 attempts** on the row.
2. A non-empty pick sends the worker into Cashfree auth
   (`/payout/v1/authorize`), which fails — and has ALWAYS failed:
   `engineer_payouts` contains **zero rows that ever reached
   `processed`**. The Cashfree credentials (set 2026-06-03) have never
   authenticated successfully.
3. Auth failure → HTTP 503 → `curl --fail-with-body` fails the step →
   the run fails. The row is never dead-lettered because the 5-attempt
   cap lives in the `processing`-reaper (`requeue_stuck_engineer_payouts`),
   and this row keeps cycling through `queued`.
4. The "Alert on cron failure" canary — designed to open a sticky GitHub
   issue, with a comment in the yml literally memorializing "gateway 401
   silently killed cron for weeks before founder noticed" — **failed on
   every run too**: the workflow has no `permissions:` block, the default
   token is read-only, and `issues.create` was rejected. The watchdog
   could not bark, which reads as "no issue filed, nothing wrong".

Gateway auth and `CRON_TICK_SECRET` were ruled out by contrast:
`cron-tick-hourly` succeeds using the same two repo secrets.

**Contained (autonomous, test-data-only):** the ₹18.60 test payout is
dead-lettered to `failed` via `record_engineer_payout_dispatch()` with a
full audit reason — faithful to the worker's own 5-attempt design, some
1,367 attempts late. Queue now empty; `pick` returns 0; the worker's next
scheduled run takes its empty-queue `200 processed: 0` path *before*
touching Cashfree, so the failure loop stops without masking anything.

**Founder decisions, unchanged by the containment:**

1. **The payment rail.** Cashfree payouts have never worked in this
   environment. Either fix/replace the `CASHFREE_*` credentials, or
   finish the RazorpayX migration the webhook side already speaks
   (`payouts-webhook`, `razorpayx_status`), or unset the Cashfree
   credentials entirely — the worker's own designed off-switch, making it
   report `configured: false` instead of failing. Until then, the FIRST
   REAL payout queued at launch will put the worker straight back into
   this failure loop.
2. **Merge the canary fix to `main`.** `permissions: {contents: read,
   issues: write}` added to the worker workflow on this branch takes
   effect only from the default branch. Same merge can carry the
   Code Red `*/5` workflow if wanted.

---

## SAME DISEASE, DIFFERENT LIMB (2026-09-05, round3810): push notifications have NEVER been dispatched

While censusing edge functions for missing callers (how the invoice
digest was found), the push pipeline turned out to be unwired at **both**
ends:

* The `notifications_dispatch_push` trigger IS live on
  `public.notifications` — but it deliberately no-ops unless two database
  GUCs are set, and **neither `app.push_webhook_url` nor
  `app.push_webhook_secret` is set at any level** (checked
  `pg_db_role_setting`: the only `app.*` GUC on the database is
  `app.settings.jwt_exp`). Every notification INSERT since April took the
  silent no-op branch.
* The `send_push_notification` edge function needs `FCM_PROJECT_ID`,
  `FCM_SERVICE_ACCOUNT_JSON` and `PUSH_WEBHOOK_SECRET` — **none of the
  three exists in the function secrets.**

So the app registers FCM tokens, r1499 shipped push-kind deep links, the
dispatcher and the sender both exist — and no push has ever left the
building. `net._http_response` corroborates: zero pg_net calls recorded.

**This needs a credential only the founder can produce** (the Firebase
service-account JSON), so it is deliberately NOT wired here. The
five-minute runbook once you have it:

```bash
# 1. generate one shared secret
PUSH_SECRET=$(openssl rand -hex 32)

# 2. function side
supabase secrets set \
  FCM_PROJECT_ID=<firebase-project-id> \
  FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)" \
  PUSH_WEBHOOK_SECRET="$PUSH_SECRET"

# 3. database side (run as postgres; new connections pick it up)
ALTER DATABASE postgres SET app.push_webhook_url =
  'https://eyswaywvtartpvtoxtdr.supabase.co/functions/v1/send_push_notification';
ALTER DATABASE postgres SET app.push_webhook_secret = '<the same PUSH_SECRET>';

# 4. prove it: INSERT a notification for a test account, then
SELECT status_code, created FROM net._http_response ORDER BY created DESC LIMIT 3;
```

Do NOT commit the secret value anywhere — that is why no migration sets
these GUCs.

## Completing the wiring ledger (round3810 census)

| edge function | callers | verdict |
|---|---|---|
| `send_push_notification` | pg_net trigger (no-oping) | **unwired at both ends — runbook above** |
| `export_nabh_bundle` | none anywhere | fully-built auditor bundle with no UI trigger on this branch; the "Asset history → NABH" surface lives in the deferred 59-feature set (founder's scope call) |
| `ingest_openfda` | none | manual-by-design catalog seeder (own secret, idempotent cursor) — fine |
| every other function | ≥1 real caller | wired |

Also staged: `.github/workflows/cron-tick-code-red.yml` restores the
declared `*/5` Code Red cadence — **inert until merged to `main`**, same
merge as the payouts-worker canary fix.

---

## The `main` merge, pre-staged (2026-09-05)

Branch **`ops/main-workflow-fixes`** (commit `584aa28f`) is cut directly
from `origin/main` and contains ONLY the two workflow changes — the
payouts-canary `permissions` grant and the new Code Red `*/5` workflow —
so merging it carries zero exposure to the diverged ops history:

    https://github.com/ganeshnaik166/equipseva-android/pull/new/ops/main-workflow-fixes

Merge that, and both scheduled-workflow fixes go live; nothing else about
`main` changes.

---

## VERDICTS IN (2026-09-06 morning): both scheduled paths confirmed green end-to-end

Overnight, GitHub's scheduler delivered the two proofs that local
verification could not:

* **`cron-tick-hourly`: three consecutive successes post-deploy**
  (2026-09-05 21:08, 23:48, 2026-09-06 04:27 UTC). The hourly group —
  including the three round3807 additions (refund-authorization reaper,
  stranded-AMC-order reaper, Code Red sweep) — runs end-to-end through
  the real GitHub → gateway → edge-function → RPC path with the real
  secret.
* **`engineer-payouts-worker`: three consecutive successes**
  (23:08, 00:58, 05:48) — after months in which every single run failed.
  The round3809 dead-letter fixed it exactly as predicted: empty queue →
  the worker exits `200 processed: 0` before touching Cashfree.

Still pending its first post-deploy fire: **`cron-tick-daily`** (last ran
07:29 UTC on 2026-09-05, before the deploy; next due ~07:30 UTC daily).
That run is the first exercise of the 16 new daily slots, including
`invoice-digest`. A slot failure surfaces in the run output as
`{slot, error: "slot_failed", error_code: <SQLSTATE|H<status>>}` — every
underlying RPC was already proven live by direct execution, so the
residual risk is confined to the TS slot wrappers and the digest's
Resend call.

Also salvaged into the repo: `scripts/verify/orderby_recheck.sql` — the
self-contained monotonicity probe for the 73 ORDER BY pairs that were
undetermined at repair time (the round3798/3801 footers pointed at a
session scratchpad path that no longer exists).

---

## First daily-tick FAILURE, most likely transient (2026-09-06 07:43 UTC)

The first post-deploy `cron-tick-daily` run (07:43 UTC) — the first
exercise of the 16 new daily slots — FAILED at the `POST ?slot=daily`
step. Diagnosis so far:

* **Every daily RPC runs clean as service_role.** Re-executed all 24
  functions the daily group calls (the whole list, plus
  run_daily_reconciliation) in a single rolled-back service_role
  transaction: zero errors. So the failure is NOT in the SQL.
* **invoice-digest is not it:** get_invoice_digest_payload returns 0 rows
  in the window, so that slot takes its clean early-exit before ever
  calling Resend.
* **Most likely cause: the PGRST002 schema-cache wedge.** Around the same
  window, every app RPC was returning HTTP 503 / PGRST002 ("Could not
  query the database for the schema cache. Retrying.") — the aftermath of
  this week's heavy DDL. `NOTIFY pgrst, 'reload schema'` cleared it, and
  the gateway is healthy now (cron-tick returns 401 on a bad secret, not
  503). A slot RPC call landing during that reload would 500, failing the
  step exactly as observed.
* **The run is self-diagnosing regardless:** cron-tick returns a 500 body
  `{ok:false, slot:"daily", results:[{slot, error:"slot_failed",
  error_code:<SQLSTATE|H<status>>}, ...]}`, and the workflow's
  `curl --fail-with-body` prints it into the run log. Opening
  run 34019901270 shows exactly which slot(s) failed and why — the
  diagnosability the round441 error_code design exists for.

NOT patched, because there is nothing to patch if it is the transient it
appears to be: the daily group is idempotent, and the next scheduled tick
(~07:30 UTC tomorrow) will confirm green. If it fails again, the run-log
body names the slot; a slot that fails deterministically (vs the
schema-cache flake) then gets a targeted fix. The hourly group has run
green repeatedly through this same period, which is consistent with a
brief cache reload rather than a broken daily slot.

## 2026-09-07 — first ledger read: "hourly" actually fires every ~3 h (GitHub scheduler), ledger is faithful

`public.cron_tick_runs` (r3813) vs the GitHub Actions run list for `cron-tick-hourly.yml`, same window:

| source | runs since r3813 deploy (2026-09-06 ~10:25 UTC → 2026-09-07 03:30 UTC) |
|---|---|
| `cron_tick_runs` rows, slot=hourly | 5, all `ok`, no `failed_slots`, avg 4.8 s |
| GitHub scheduled runs of cron-tick-hourly | 5 (13:36, 16:56, 19:05, 21:16, 23:47) — all success |

So the ledger matches the runs 1:1 (no lost inserts), and the gap is upstream: over the last 44 h the
`0 * * * *` schedule produced 14 runs, i.e. one every **~3.1 h**, with individual gaps of 2 h 10 m to
5 h 7 m. This is documented GitHub behaviour (scheduled workflows are queued with low priority and
delayed or dropped under load); it is not a bug in cron-tick. Consequences to plan around:

- Every "hourly" slot (stale-job reaper, tier cache, SLA monitors, escrow auto-release …) has an
  effective worst-case latency of ~5 h, not 1 h. Copy that promises "within the hour" is wrong.
- The staged Code Red `*/5` workflow will NOT page within 5 minutes on GitHub's scheduler; expect the
  same multi-hour jitter. A real pager needs an external trigger (Supabase pg_cron once enabled, or a
  cheap always-on ping such as a Cloudflare Worker cron / UptimeRobot hitting the edge function).
- `engineer-payouts-worker` shows the same pattern (runs every ~2 h against its schedule) and stays green.
- `cron-tick-daily`: 2026-09-06 07:43 failure already diagnosed as the transient PGRST002 wedge; the
  2026-09-07 run had not fired by 03:30 UTC (expected ~07:30–08:00). Read it from the ledger:
  `select * from public.founder_cron_tick_recent(10)` — a red row carries `failed_slots` + per-slot `results`.
