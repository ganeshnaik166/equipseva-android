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
