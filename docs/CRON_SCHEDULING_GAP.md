# Scheduled-job coverage gap (found 2026-09-03, round3794)

**Status: real, currently harmless, becomes live at launch. Needs a
go/no-go from the founder, not a code cleanup.**

## Summary

The migrations declare **31 distinct scheduled jobs**. **11 actually have
a scheduler. 20 have none at all.** Nothing failed loudly, because every
`cron.schedule(...)` call site is either guarded on
`extname = 'pg_cron'` or wrapped in `EXCEPTION WHEN OTHERS THEN RAISE
NOTICE`, so the entire set failed silently at migration time.

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

**RPC exists in prod — wiring it into a `cron-tick` slot is all that is
needed (14):**

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

**RPC does NOT exist — the job declaration was aspirational, so there is
nothing to schedule (4):** `purge_old_analytics_events`,
`purge_old_nabh_export_audit`, `purge_old_investor_share_view_log`,
`capture_db_storage_snapshot`. The last one is why
`founder_db_storage_snapshots_summary` has never had a snapshot to
report. The three purges are **DPDP retention obligations with no
implementation at all** — worth confirming against the DPDP commitments
before launch.

`founder_invoice_digest_daily` is the 20th: there IS a
`founder_invoice_digest` edge function, but no workflow invokes it.

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
2. **Decide on the 4 missing RPCs** — in particular whether the three
   retention purges are required by the DPDP posture. If so they are real
   work, not wiring.
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
