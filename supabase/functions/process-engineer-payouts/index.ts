// Supabase edge function: process-engineer-payouts
//
// Round 432: rewritten to use Cashfree Payouts after RazorpayX hard-
// rejected sole proprietorships on 2026-06-03 (the founder's
// EquipSeva is sole prop with GSTIN but no CIN/MCA registration).
// Cashfree accepts sole prop, has a similar HTTP API surface, and
// charges ~₹2.5/transfer (cheaper than RazorpayX's ₹4).
//
// What stays the same:
//   * X-Cron-Secret auth, called from the 5-minute GitHub Actions cron
//   * pick_engineer_payouts_for_processing RPC (provider-agnostic)
//   * record_engineer_payout_dispatch RPC (provider-agnostic)
//   * Idempotency via our payout_id passed as Cashfree's transferId
//
// What changed:
//   * env vars: CASHFREE_CLIENT_ID + CASHFREE_CLIENT_SECRET (replaces
//     RAZORPAYX_KEY_ID/SECRET/ACCOUNT_NUMBER). Optional
//     CASHFREE_PAYOUTS_BASE_URL override for staging.
//   * Single-call beneficiary creation (combines RazorpayX's contact +
//     fund_account into one Cashfree concept).
//   * Bearer-token auth (cached per invocation for the 4-min worker
//     window; Cashfree tokens expire in 10 min).
//   * Amount sent in RUPEES (not paise) as decimal string — Cashfree's
//     convention. Our DB stays in paise.
//   * engineer_payout_methods.razorpay_contact_id is now repurposed to
//     hold the Cashfree beneId (cached so we skip re-adding the
//     beneficiary on every payout). razorpay_fund_account_id stays
//     NULL on Cashfree paths.
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_TICK_SECRET,
//   CASHFREE_CLIENT_ID, CASHFREE_CLIENT_SECRET.
// Optional:
//   CASHFREE_PAYOUTS_BASE_URL (default "https://payout-api.cashfree.com").

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type PickedRow = {
  payout_id: string;
  engineer_user_id: string;
  amount_paise: number;
  attempts: number;
  method_id: string | null;
  method_kind: string | null;
  vpa: string | null;
  bank_account_holder: string | null;
  bank_name: string | null;
  ifsc: string | null;
  account_number_encrypted: string | null;
  account_number_last4: string | null;
  razorpay_contact_id: string | null;        // repurposed: Cashfree beneId
  razorpay_fund_account_id: string | null;   // unused on Cashfree path
  job_number: string;
};

type DispatchResult = {
  payout_id: string;
  outcome: "processing" | "failed" | "no_method";
  reason?: string;
  cashfree_reference_id?: string;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

function timingSafeEq(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Cashfree beneId / transferId must be alphanumeric ≤50 chars. */
function sanitiseId(uuid: string): string {
  return uuid.replace(/[^a-zA-Z0-9]/g, "").slice(0, 50);
}

/** Cashfree expects amount in rupees as a decimal string with 2 dp. */
function paiseToRupeeString(paise: number): string {
  const r = Math.floor(paise) / 100;
  return r.toFixed(2);
}

let cachedToken: { token: string; expiresAt: number } | null = null;

async function cashfreeAuth(baseUrl: string, clientId: string, clientSecret: string): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 30 > nowSec) {
    return cachedToken.token;
  }
  const resp = await fetch(`${baseUrl}/payout/v1/authorize`, {
    method: "POST",
    headers: {
      "X-Client-Id": clientId,
      "X-Client-Secret": clientSecret,
    },
  });
  const body = await resp.json().catch(() => ({}));
  if (!resp.ok || (body as { status?: string })?.status !== "SUCCESS") {
    const msg = (body as { message?: string })?.message ?? `cashfree auth ${resp.status}`;
    throw new Error(`cashfree auth failed: ${msg}`);
  }
  const data = (body as { data: { token: string; expiry?: number } }).data;
  cachedToken = {
    token: data.token,
    // Default 10-min expiry per Cashfree docs; treat conservatively.
    expiresAt: nowSec + Math.min(data.expiry ?? 600, 600),
  };
  return data.token;
}

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
  if (!timingSafeEq(got, expectedSecret)) {
    return json(401, { ok: false, code: "unauthenticated", message: "bad cron secret" });
  }

  const url = new URL(req.url);
  const limit = Math.max(1, Math.min(parseInt(url.searchParams.get("limit") ?? "25", 10) || 25, 100));

  const admin = createClient(supabaseUrl, serviceKey);

  const clientId = Deno.env.get("CASHFREE_CLIENT_ID");
  const clientSecret = Deno.env.get("CASHFREE_CLIENT_SECRET");
  // Round 443: auto-pick the base URL from the credential shape so a
  // half-configured deploy (test creds, prod URL default) doesn't
  // dead-letter the entire payout queue. Cashfree test creds are
  // tagged: client IDs start with "TEST", secrets contain "_test_".
  // Hitting prod with test creds returns a generic 500
  // "Internal Server Error" — opaque enough to look like Cashfree-side
  // flakiness, which is exactly what bit us on 2026-06-01..2026-06-04.
  // Explicit env override still wins so the user can pin a URL.
  const isTestCreds =
    (clientId ?? "").startsWith("TEST") ||
    (clientSecret ?? "").includes("_test_");
  const baseUrl =
    Deno.env.get("CASHFREE_PAYOUTS_BASE_URL") ??
    (isTestCreds ? "https://payout-gamma.cashfree.com" : "https://payout-api.cashfree.com");
  if (!clientId || !clientSecret) {
    console.log("process-engineer-payouts: CASHFREE_* not configured, skipping");
    return json(200, { ok: true, configured: false, processed: 0 });
  }
  console.log(`process-engineer-payouts: using ${isTestCreds ? "SANDBOX" : "PROD"} baseUrl=${baseUrl}`);

  // Round 448: pick the queue FIRST. If nothing to do, return cleanly
  // without hitting Cashfree — saves an auth round-trip every 5 min and
  // keeps the cron green when the queue's idle (the typical state) even
  // if Cashfree sandbox is misbehaving externally (which it does
  // intermittently — see project_cashfree_sandbox_broken_2026_06_04).
  const pickRes = await admin.rpc("pick_engineer_payouts_for_processing", { p_limit: limit });
  if (pickRes.error) {
    console.error("pick rpc failed", pickRes.error);
    return json(500, { ok: false, code: "pick_failed", message: pickRes.error.message });
  }
  const picked: PickedRow[] = (pickRes.data as PickedRow[] | null) ?? [];
  if (picked.length === 0) {
    return json(200, { ok: true, configured: true, processed: 0 });
  }

  // Auth ONLY after we know there's work to do.
  let token: string;
  try {
    token = await cashfreeAuth(baseUrl, clientId, clientSecret);
  } catch (err) {
    console.error("cashfree auth", err);
    // Round 448: rows are claimed (status='processing') but we can't
    // dispatch them. Revert directly to 'queued' so the next tick can
    // retry without waiting on the round-445 reaper's 30min window.
    // The reaper still owns the 'permanently stuck' case (worker crash
    // mid-batch where this requeue itself doesn't run).
    const ids = picked.map((r) => r.payout_id);
    await admin
      .from("engineer_payouts")
      .update({
        status: "queued",
        razorpay_payout_id: null,
        razorpayx_status: null,
      })
      .in("id", ids);
    return json(503, {
      ok: false,
      code: "cashfree_unavailable",
      message: "auth failed — picked rows requeued",
      requeued: picked.length,
    });
  }

  // Round 462: respect caller-disconnect + cap the total in-flight
  // time. Picked rows that don't get processed within the budget stay
  // at 'processing' until the round 445 reaper rescues them on the
  // next hourly tick. Without this, a 100-row pick on a degraded
  // Cashfree connection could hold the edge fn open for many minutes
  // past client disconnect, burning Edge minutes + blocking the next
  // 5-min cron tick which uses `concurrency: cancel-in-progress: false`.
  const startedAt = Date.now();
  const TOTAL_BUDGET_MS = 4 * 60 * 1000; // 4 min, below Supabase Edge 5-min default
  const results: DispatchResult[] = [];
  for (const row of picked) {
    if (req.signal.aborted) {
      console.warn("process-engineer-payouts: client disconnected mid-batch");
      break;
    }
    if (Date.now() - startedAt > TOTAL_BUDGET_MS) {
      console.warn("process-engineer-payouts: total time budget exceeded mid-batch", {
        processed: results.length,
        remaining: picked.length - results.length,
      });
      break;
    }
    try {
      results.push(await processOne(admin, row, baseUrl, token));
    } catch (err) {
      console.error("payout error", row.payout_id, err);
      await admin.rpc("record_engineer_payout_dispatch", {
        p_payout_id: row.payout_id,
        p_status: "failed",
        p_failure_reason: String((err as Error)?.message ?? err).slice(0, 240),
      });
      results.push({ payout_id: row.payout_id, outcome: "failed", reason: String(err) });
    }
  }

  const counts = {
    processing: results.filter((r) => r.outcome === "processing").length,
    failed: results.filter((r) => r.outcome === "failed").length,
    no_method: results.filter((r) => r.outcome === "no_method").length,
  };
  return json(200, { ok: true, configured: true, processed: picked.length, counts, results });
});

async function processOne(
  admin: SupabaseClient,
  row: PickedRow,
  baseUrl: string,
  token: string,
): Promise<DispatchResult> {
  if (!row.method_id || !row.method_kind) {
    await admin.rpc("record_engineer_payout_dispatch", {
      p_payout_id: row.payout_id,
      p_status: "no_method",
    });
    return { payout_id: row.payout_id, outcome: "no_method" };
  }

  // Ensure beneId. Cached on engineer_payout_methods.razorpay_contact_id
  // — same column, repurposed for Cashfree's identifier.
  let beneId = row.razorpay_contact_id;
  if (!beneId) {
    beneId = await cashfreeAddBeneficiary(baseUrl, token, row);
  }

  // Cashfree's transferId is our payout_id (sanitised). Re-submitting
  // the same transferId returns the existing transfer's status —
  // built-in idempotency, no double-spend.
  const transferId = sanitiseId(row.payout_id);
  const transferMode = row.method_kind === "upi" ? "upi" : "banktransfer";
  const resp = await fetch(`${baseUrl}/payout/v1/requestTransfer`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      beneId,
      amount: paiseToRupeeString(row.amount_paise),
      transferId,
      transferMode,
      remarks: `EquipSeva ${row.job_number}`.slice(0, 100),
    }),
  });
  const body = await resp.json().catch(() => ({}));
  // Cashfree returns 200 with status=SUCCESS on accept, status=ERROR
  // on validation failures. Always inspect the body.
  const cfStatus = (body as { status?: string })?.status;
  const data = (body as { data?: { referenceId?: string | number; utr?: string } }).data ?? {};
  const refId = data.referenceId != null ? String(data.referenceId) : null;
  if (!resp.ok || cfStatus === "ERROR") {
    const errMsg =
      (body as { message?: string; subCode?: string })?.message ??
      `cashfree ${resp.status}`;
    const subCode = (body as { subCode?: string })?.subCode ?? "";
    // Round 445: Cashfree returns 200 + status=ERROR + subCode=409 +
    // message containing 'already exists' / 'already in process' on
    // re-submission of the same transferId — even when the original
    // transfer succeeded. Treating that as a clean failure flips our
    // row to 'failed' and loses the referenceId so the eventual
    // TRANSFER_SUCCESS webhook can't find the row (it looks up by
    // razorpay_payout_id). Money moved, our DB says failed, engineer
    // chases the founder. Detect the duplicate signal and route to
    // 'processing' (preserving any referenceId Cashfree returned on
    // the error body) so the webhook can reconcile later.
    const looksDuplicate =
      subCode === "409" ||
      /already.*exist/i.test(errMsg) ||
      /already.*in.*process/i.test(errMsg) ||
      /duplicate.*transfer/i.test(errMsg);
    if (looksDuplicate) {
      // Round 468: when Cashfree's duplicate 409 omits referenceId in
      // the error body (which it does inconsistently), fall back to
      // GET /payout/v1/getTransferStatus/transferId/<id> to fetch the
      // original transfer's referenceId. Without this fallback, the
      // dispatch RPC would store razorpay_payout_id=NULL on the
      // re-submission, so the eventual TRANSFER_SUCCESS webhook
      // couldn't match — money moved, DB stayed stuck. Round 466
      // preserved razorpay_payout_id on requeue but couldn't help if
      // it was NULL to begin with.
      let recoveredRefId = refId;
      if (recoveredRefId == null) {
        try {
          const lookupResp = await fetch(
            `${baseUrl}/payout/v1/getTransferStatus?transferId=${encodeURIComponent(transferId)}`,
            {
              method: "GET",
              headers: { "Authorization": `Bearer ${token}` },
              signal: AbortSignal.timeout(8_000),
            },
          );
          const lookupBody = await lookupResp.json().catch(() => ({}));
          const lookupData = (lookupBody as { data?: { transfer?: { referenceId?: string | number } } }).data ?? {};
          const looked = lookupData.transfer?.referenceId;
          if (looked != null) {
            recoveredRefId = String(looked);
            console.log(
              "process-engineer-payouts: recovered referenceId via GET /getTransferStatus",
              row.payout_id,
              recoveredRefId,
            );
          } else {
            console.warn(
              "process-engineer-payouts: GET /getTransferStatus returned no referenceId either",
              row.payout_id,
              JSON.stringify(lookupBody).slice(0, 200),
            );
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          console.warn("process-engineer-payouts: refId fallback threw", row.payout_id, msg);
        }
      }
      console.warn(
        "process-engineer-payouts: duplicate transferId — routing to processing",
        row.payout_id,
        errMsg,
        `refId=${recoveredRefId ?? "null"}`,
      );
      await admin.rpc("record_engineer_payout_dispatch", {
        p_payout_id: row.payout_id,
        p_status: "processing",
        p_razorpay_payout_id: recoveredRefId,
        p_razorpayx_status: "DUPLICATE_REQUEUE",
        p_razorpay_contact_id: beneId,
      });
      return {
        payout_id: row.payout_id,
        outcome: "processing",
        cashfree_reference_id: recoveredRefId ?? undefined,
        duplicate_transfer: true,
      };
    }
    // Round 466: distinguish Cashfree 5xx (their infra outage) from
    // Cashfree 4xx-style ERROR (engineer's VPA/bank rejected). 5xx
    // is retryable — flip back to queued + bump attempts so the next
    // tick re-dispatches. 4xx stays terminal (engineer must fix
    // their payout method). Before this fix, a 30-second Cashfree
    // blip permanently killed every in-flight payout.
    const is5xx = resp.status >= 500 && resp.status < 600;
    if (is5xx) {
      console.warn(
        "process-engineer-payouts: Cashfree 5xx — requeuing for retry",
        row.payout_id,
        resp.status,
      );
      await admin.rpc("record_engineer_payout_dispatch", {
        p_payout_id: row.payout_id,
        p_status: "queued",
        p_failure_reason: `Cashfree 5xx ${resp.status}: ${errMsg}`.slice(0, 240),
        p_razorpay_contact_id: beneId,
      });
      return { payout_id: row.payout_id, outcome: "failed", reason: `5xx_retry: ${errMsg}` };
    }
    await admin.rpc("record_engineer_payout_dispatch", {
      p_payout_id: row.payout_id,
      p_status: "failed",
      p_failure_reason: errMsg.slice(0, 240),
      p_razorpay_contact_id: beneId,
    });
    return { payout_id: row.payout_id, outcome: "failed", reason: errMsg };
  }
  await admin.rpc("record_engineer_payout_dispatch", {
    p_payout_id: row.payout_id,
    p_status: "processing",
    p_razorpay_payout_id: refId,           // repurposed: Cashfree referenceId
    p_razorpayx_status: cfStatus ?? "PENDING",
    p_razorpay_contact_id: beneId,
  });
  return {
    payout_id: row.payout_id,
    outcome: "processing",
    cashfree_reference_id: refId ?? undefined,
  };
}

async function cashfreeAddBeneficiary(
  baseUrl: string,
  token: string,
  row: PickedRow,
): Promise<string> {
  // Round 468: beneId is derived from the METHOD id, not the engineer_user_id.
  // Old engineer-keyed derivation collided across multiple methods of the
  // same engineer — Cashfree's beneId is permanently mapped to the FIRST
  // registered VPA, so when an engineer rotated UPI/bank, all subsequent
  // payouts continued going to the OLD destination. Method-keyed beneId
  // gives each method its own Cashfree beneficiary entry.
  if (!row.method_id) throw new Error("missing method_id (round 468 fix)");
  const beneId = sanitiseId(row.method_id);
  const name = row.method_kind === "upi"
    ? (row.vpa ?? "engineer")
    : (row.bank_account_holder ?? "engineer");
  // Cashfree minimum required fields differ per mode but all need
  // beneId + name + email + phone + address1.
  const payload: Record<string, unknown> = {
    beneId,
    name: name.slice(0, 80),
    // Cashfree requires email + phone — use placeholders since we
    // don't surface engineer email here and the engineer may not have
    // populated it. Cashfree's validation is loose on these fields.
    email: `payouts+${beneId}@equipseva.com`,
    phone: "9999999999",
    address1: "EquipSeva engineer",
  };
  if (row.method_kind === "upi") {
    if (!row.vpa) throw new Error("missing vpa");
    payload.vpa = row.vpa;
  } else {
    if (!row.ifsc || !row.account_number_encrypted || !row.bank_account_holder) {
      throw new Error("missing bank fields");
    }
    payload.bankAccount = row.account_number_encrypted;
    payload.ifsc = row.ifsc;
  }

  const resp = await fetch(`${baseUrl}/payout/v1/addBeneficiary`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = await resp.json().catch(() => ({}));
  const status = (body as { status?: string; subCode?: string; message?: string })?.status;
  // Cashfree returns SUCCESS for new beneficiary; ERROR with
  // subCode=409 + message containing "already exists" if the beneId
  // is already there (which means we cached it once before and the
  // method row got reset somehow — safe to reuse).
  const msg = (body as { message?: string })?.message ?? "";
  if (status === "SUCCESS" || /already exists/i.test(msg)) {
    return beneId;
  }
  throw new Error(`cashfree addBeneficiary failed: ${msg || `status ${resp.status}`}`);
}
