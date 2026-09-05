// Supabase edge function: cron-tick
//
// v2.1 PR-D20 — Free-tier substitute for pg_cron. Lets the operator
// fire the time-based housekeeping helpers (PR-D4 escrow auto-release,
// PR #251 cost-revision expiry, PR #252-#253 TTL purges) from any
// external cron source: cron-job.org, GitHub Actions, EasyCron, your
// own server crontab — anything that can POST.
//
// PR-D39 wires the actual GitHub Actions schedule:
//   * .github/workflows/cron-tick-hourly.yml — slot=hourly
//   * .github/workflows/cron-tick-daily.yml  — slot=daily at 03:00 UTC
// Both POST here with X-Cron-Secret = repo secret CRON_TICK_SECRET.
//
// The matching pg_cron migration (20260529100000) self-installs on
// Pro+; on Free it sits dormant and this function is the substitute.
// Once the project moves to Pro, this can be deleted (or kept as a
// belt-and-suspenders backup).
//
// Auth: shared secret in the X-Cron-Secret header, compared against
// the CRON_TICK_SECRET env var. Rejects without it. The function then
// uses the service-role key to call SECDEF helpers — same elevated
// scope pg_cron would have.
//
// Body: no input expected. Optional `?slot=foo` query param lets the
// operator schedule different slots independently (e.g. run TTL
// purges only at 03:00 IST, escrow every hour). `slot=all` (default)
// runs everything.
//
// Idempotent across overlapping runs: each helper either uses
// FOR UPDATE SKIP LOCKED (process_due_repair_job_escrow_releases) or
// is naturally re-runnable (TTL purges + expire helpers). Concurrent
// invocations don't double-process.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type SlotResult = {
  slot: string;
  ok: boolean;
  rows?: number;
  error?: string;
  // PostgreSQL SQLSTATE code (5 chars, public per PG docs — e.g.
  // 23502 = not_null_violation). Round 441: surfacing it lets the
  // cron runbook diagnose slot failures without round-tripping to
  // Supabase function logs. NOT sensitive — no message, no table
  // names, no row data.
  error_code?: string;
  duration_ms: number;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

serve(async (req) => {
  if (req.method !== "POST") {
    return json(405, { ok: false, code: "bad_request", message: "POST only" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const expectedSecret = Deno.env.get("CRON_TICK_SECRET");
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, code: "server_error", message: "edge fn not configured" });
  }
  if (!expectedSecret) {
    return json(500, {
      ok: false,
      code: "server_error",
      message: "CRON_TICK_SECRET unset — refusing to run",
    });
  }
  const got = req.headers.get("x-cron-secret") ?? "";
  // Constant-time compare so timing leaks can't recover the secret.
  if (got.length !== expectedSecret.length) {
    return json(401, { ok: false, code: "unauthenticated", message: "bad cron secret" });
  }
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got.charCodeAt(i) ^ expectedSecret.charCodeAt(i);
  if (diff !== 0) {
    return json(401, { ok: false, code: "unauthenticated", message: "bad cron secret" });
  }

  const url = new URL(req.url);
  const slot = url.searchParams.get("slot") ?? "all";
  const admin = createClient(supabaseUrl, serviceKey);

  const slots: Record<string, () => Promise<{ rows?: number }>> = {
    "escrow-release": async () => {
      const { data, error } = await admin.rpc("process_due_repair_job_escrow_releases");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "expire-cost-revisions": async () => {
      const { data, error } = await admin.rpc("expire_stale_cost_revisions");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-notifications": async () => {
      const { data, error } = await admin.rpc("purge_old_notifications");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-content-reports": async () => {
      const { data, error } = await admin.rpc("purge_old_content_reports");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-device-integrity": async () => {
      const { data, error } = await admin.rpc("purge_old_device_integrity_checks");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-virtual-calls": async () => {
      const { data, error } = await admin.rpc("purge_old_virtual_call_sessions");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 296 — wire v2.1 AMC cron helpers that have been defined
    // since 20260511100000 but were never invoked. Without these,
    // AMC contracts don't auto-create maintenance visits at their
    // next_visit_at, and don't auto-renew at end_date. Feature was
    // shipped server-side but degraded in prod for the absence of
    // an invocation.
    "amc-create-visits": async () => {
      const { data, error } = await admin.rpc("auto_create_due_amc_visits");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 445 — reaper for engineer_payouts rows stuck in 'processing'.
    // Worker crash mid-batch or Cashfree event drop leaves rows orphaned
    // (no webhook ever arrives). Default: rows older than 30min get
    // requeued; after 5 attempts they dead-letter to 'failed' so an
    // operator surfaces them in the founder admin dashboard.
    "payouts-reaper": async () => {
      const { data, error } = await admin.rpc(
        "requeue_stuck_engineer_payouts",
        { p_max_age: "30 minutes", p_max_attempts: 5 },
      );
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 446 — sweep for AMC SLA response-time breaches on
    // auto-created visits that never had a status UPDATE fire the
    // existing trigger. Idempotent via the partial-unique index on
    // amc_sla_breaches(amc_contract_id, visit_id, breach_type='response_time').
    "amc-sla-sweep": async () => {
      const { data, error } = await admin.rpc("sweep_amc_sla_unresponded_visits");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "amc-auto-renew": async () => {
      const { data, error } = await admin.rpc("auto_renew_expiring_amc_contracts");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 313 — v1 AMC renewal notifier. auto_renew_expiring_amc_contracts
    // enqueues renewal attempts but no worker drains them yet (needs
    // Razorpay subscriptions for off-session charge). v1 fallback:
    // notify the hospital that their AMC is expiring so they can
    // manually renew. Idempotent per contract via
    // amc_contracts.last_renewal_notification_at.
    "amc-renewal-notify": async () => {
      const { data, error } = await admin.rpc("notify_expiring_amc_contracts");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 322 — flip lapsed (active + end_date < today) AMC
    // contracts to 'expired'. v2.1 shipped 'expired' as a valid status
    // but no transition fn existed, so contracts stuck 'active' past
    // term and kept auto-creating visits. Idempotent.
    "expire-amc-contracts": async () => {
      const { data, error } = await admin.rpc("expire_lapsed_amc_contracts");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 323 — TTL purge for spot_audit_invitations that expired
    // >30 days ago AND have no response (responded-to invites stay
    // for the engineer audit trail). Without this, invitations grow
    // unbounded once the 1-in-20 post-completion nudge ramps.
    "purge-spot-audit-invitations": async () => {
      const { data, error } = await admin.rpc("purge_old_spot_audit_invitations");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 332 — TTL purge for chat_message_moderation_events older
    // than 90 days. The table records pre-masking PII users tried
    // to share (Aadhaar/PAN/phone/email); indefinite retention
    // defeats the chat-masking redaction. DPDP-driven retention.
    "purge-chat-moderation-events": async () => {
      const { data, error } = await admin.rpc("purge_old_chat_moderation_events");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Round 304 — TTL purge for phone_otp_requests; the table is
    // append-only via phone_otp_can_request and would grow unbounded
    // without this. 7-day retention is plenty for fraud forensics
    // (the rate-limit window itself is 1 hour).
    "purge-phone-otp-requests": async () => {
      const { data, error } = await admin.rpc("purge_old_phone_otp_requests");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },

    // =================================================================
    // Round 3807 — founder-approved wiring of the 19 declared-but-never-
    // scheduled jobs (docs/CRON_SCHEDULING_GAP.md). Every migration that
    // declared these called cron.schedule() behind an `extname='pg_cron'`
    // guard or an EXCEPTION handler, and pg_cron has never been installed
    // on this project — so none of them had EVER run. All 18 RPCs already
    // existed in prod; this file was the only missing piece. Blast radius
    // was measured before enabling (pre-launch DB: 39 repair jobs, 0 held
    // escrow), which is exactly why now is the cheapest time to switch
    // them on.
    // =================================================================

    // --- hourly additions ---------------------------------------------
    // Declared '0 * * * *': refunds authorizations expire on an hour
    // scale; AMC orders stuck in pending_payment likewise.
    "reap-refund-authorizations": async () => {
      const { data, error } = await admin.rpc("reap_expired_refund_authorizations");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "reap-stranded-amc-orders": async () => {
      const { data, error } = await admin.rpc("reap_stranded_pending_payment_amc_contracts");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Declared '*/5 * * * *' (Code Red safety-escalation timeout). GitHub
    // Actions cannot honour a 5-minute cadence from this repo without a
    // dedicated workflow on the default branch, which is frozen — so this
    // runs HOURLY for now. Hourly beats the current never by a lot; the
    // 5-minute upgrade path is a one-line workflow on main calling
    // ?slot=sweep-code-reds, documented in docs/CRON_SCHEDULING_GAP.md.
    "sweep-code-reds": async () => {
      const { data, error } = await admin.rpc("sweep_timed_out_code_reds");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },

    // --- daily additions ----------------------------------------------
    "reap-stranded-repair-jobs": async () => {
      const { data, error } = await admin.rpc("reap_stranded_requested_repair_jobs");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // run_daily_reconciliation(p_date date) is the one argumented sweep:
    // reconcile the day that has fully ELAPSED in IST, i.e. IST-yesterday.
    // (Returns the reconciliation row's uuid, not a count.)
    "daily-reconciliation": async () => {
      const istYesterday = new Date(Date.now() + (5.5 - 24) * 3600 * 1000)
        .toISOString().slice(0, 10);
      const { error } = await admin.rpc("run_daily_reconciliation", { p_date: istYesterday });
      if (error) throw error;
      return {};
    },
    // KYC renewal pair (round497 backend; functional since round3806
    // added engineers.verification_status_updated_at). Order within the
    // daily group matters loosely: schedule first, reap after, matching
    // the declared '0 21' / '15 21' ordering.
    "schedule-kyc-renewals": async () => {
      const { data, error } = await admin.rpc("schedule_engineer_kyc_renewals");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "reap-expired-kyc-renewals": async () => {
      const { data, error } = await admin.rpc("reap_expired_kyc_renewals");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Fraud triad — the declared nightly risk pipeline.
    "daily-risk-scoring": async () => {
      const { data, error } = await admin.rpc("run_daily_risk_scoring");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "scan-collusion-pairs": async () => {
      const { data, error } = await admin.rpc("scan_collusion_pairs");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "scan-duplicate-accounts": async () => {
      const { data, error } = await admin.rpc("scan_duplicate_accounts");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Backs the round3773/3774 Commission Tier + Payout Preview screens.
    // NB the bulk sweep is refresh_ALL_engineer_tier_cache();
    // refresh_engineer_tier_cache(uuid) is the per-engineer variant and
    // 42883s with no args — the dry run caught exactly that.
    "refresh-tier-cache": async () => {
      const { data, error } = await admin.rpc("refresh_all_engineer_tier_cache");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Backs the round3770 Predictive PM Calendar. Projects from signed
    // DSRs, so it stays a no-op until a DSR-submission path exists — but
    // scheduled is the correct resting state either way.
    "recompute-pm-schedules": async () => {
      const { data, error } = await admin.rpc("recompute_all_pm_schedules");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "recompute-certifications": async () => {
      const { data, error } = await admin.rpc("recompute_all_engineer_certifications");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Backs the round3777 Referral Bounty screen — without this, bounties
    // never evaluate no matter how many referees finish their first job.
    "evaluate-referrals": async () => {
      const { data, error } = await admin.rpc("evaluate_all_pending_referrals");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // DPDP retention sweeps — implemented all along, never scheduled.
    "purge-analytics-events": async () => {
      const { data, error } = await admin.rpc("analytics_events_retention_sweep");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-investor-share-views": async () => {
      const { data, error } = await admin.rpc("investor_share_view_log_retention_sweep");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    "purge-nabh-export-audit": async () => {
      const { data, error } = await admin.rpc("nabh_export_audit_retention_sweep");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // Why founder_db_storage_snapshots_summary never had a snapshot.
    "db-storage-snapshot": async () => {
      const { data, error } = await admin.rpc("db_storage_snapshot_sweep");
      if (error) throw error;
      return { rows: typeof data === "number" ? data : undefined };
    },
    // The one non-RPC job: founder_invoice_digest is a sibling edge
    // function that was deployed with no caller anywhere. It validates
    // x-webhook-secret against the SAME CRON_TICK_SECRET this function
    // holds, so we invoke it server-side and no new secret or workflow
    // is needed.
    "invoice-digest": async () => {
      const res = await fetch(`${supabaseUrl}/functions/v1/founder_invoice_digest`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${serviceKey}`,
          "x-webhook-secret": expectedSecret,
          "content-type": "application/json",
        },
        body: "{}",
      });
      if (!res.ok) {
        // Same hygiene as the RPC slots: no body echo, just the status.
        throw Object.assign(new Error("invoice digest failed"), { code: `H${res.status}` });
      }
      return {};
    },
  };

  // Slot groups for typical schedules.
  const groups: Record<string, string[]> = {
    "all": Object.keys(slots),
    // hourly: time-sensitive ones — escrow auto-release, cost-revision
    // TTL expiry, AMC visit creation (so the visit lands within the
    // hour of next_visit_at, not next-day).
    "hourly": [
      "escrow-release", "expire-cost-revisions", "amc-create-visits", "payouts-reaper", "amc-sla-sweep",
      // round3807 — declared hourly (and Code Red, declared */5, riding
      // hourly until a 5-min workflow lands on main):
      "reap-refund-authorizations", "reap-stranded-amc-orders", "sweep-code-reds",
    ],
    // daily: TTL purges off-peak + AMC auto-renewal sweep (end_date
    // is day-granular so one daily pass is plenty).
    "daily": [
      "purge-notifications",
      "purge-content-reports",
      "purge-device-integrity",
      "purge-virtual-calls",
      "purge-phone-otp-requests",
      "amc-auto-renew",
      "amc-renewal-notify",
      "expire-amc-contracts",
      "purge-spot-audit-invitations",
      "purge-chat-moderation-events",
      // round3807 — the declared-daily set that never ran (see the slot
      // comments above). schedule before reap, matching the declared
      // '0 21' / '15 21' ordering of the KYC pair.
      "reap-stranded-repair-jobs",
      "daily-reconciliation",
      "schedule-kyc-renewals",
      "reap-expired-kyc-renewals",
      "daily-risk-scoring",
      "scan-collusion-pairs",
      "scan-duplicate-accounts",
      "refresh-tier-cache",
      "recompute-pm-schedules",
      "recompute-certifications",
      "evaluate-referrals",
      "purge-analytics-events",
      "purge-investor-share-views",
      "purge-nabh-export-audit",
      "db-storage-snapshot",
      "invoice-digest",
    ],
  };

  const targets: string[] = groups[slot] ?? (slot in slots ? [slot] : []);
  if (targets.length === 0) {
    return json(400, {
      ok: false,
      code: "bad_request",
      message: `unknown slot '${slot}'. Valid: ${[...Object.keys(slots), ...Object.keys(groups)].join(", ")}`,
    });
  }

  const results: SlotResult[] = [];
  for (const t of targets) {
    const start = Date.now();
    try {
      const r = await slots[t]();
      results.push({ slot: t, ok: true, rows: r.rows, duration_ms: Date.now() - start });
    } catch (e) {
      // Don't echo raw e.message — it can carry PostgREST hints,
      // table names, row data. The response body lands in GitHub
      // Actions / cron-job.org logs (external surfaces). Log full
      // detail server-side; surface only the slot name, a stable
      // error code, and the 5-char SQLSTATE (round 441) so the cron
      // runbook can diagnose without round-tripping to dashboard logs.
      console.error(`cron-tick slot=${t} failed`, e);
      // PostgrestError shape: { code: '23502', message: '...', details: '...', hint: '...' }
      // Native Postgres exceptions thrown by supabase-js include `code`
      // on the rejected response. Extract it defensively (no PII risk —
      // SQLSTATE values are documented Postgres constants).
      const sqlstate = (typeof (e as { code?: unknown })?.code === "string")
        ? (e as { code: string }).code
        : undefined;
      // Only allow the canonical 5-char SQLSTATE form. Anything else
      // (e.g., a custom string) gets dropped to keep the surface clean.
      const safeCode = sqlstate && /^[0-9A-Z]{5}$/.test(sqlstate) ? sqlstate : undefined;
      results.push({
        slot: t,
        ok: false,
        error: "slot_failed",
        error_code: safeCode,
        duration_ms: Date.now() - start,
      });
    }
  }

  const allOk = results.every((r) => r.ok);
  return json(allOk ? 200 : 500, {
    ok: allOk,
    slot,
    targets,
    results,
  });
});
