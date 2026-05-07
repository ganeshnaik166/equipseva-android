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
  };

  // Slot groups for typical schedules.
  const groups: Record<string, string[]> = {
    "all": Object.keys(slots),
    // hourly: just the time-sensitive ones.
    "hourly": ["escrow-release", "expire-cost-revisions"],
    // daily: TTL purges off-peak.
    "daily": ["purge-notifications", "purge-content-reports", "purge-device-integrity", "purge-virtual-calls"],
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
      results.push({
        slot: t,
        ok: false,
        error: e instanceof Error ? e.message : String(e),
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
