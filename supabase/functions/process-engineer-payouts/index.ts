// Supabase edge function: process-engineer-payouts
//
// Round 424 worker. Drains the engineer_payouts queue: for each row
// status='queued' with a payout_method_id, ensures the engineer has a
// RazorpayX contact_id + fund_account_id (cache on the method row),
// calls the RazorpayX Payouts API, and stamps the result via
// record_engineer_payout_dispatch.
//
// Webhook (`razorpayx-webhook`) flips the row to 'processed' once
// RazorpayX confirms the money landed; until then the row sits at
// 'processing'.
//
// Auth: X-Cron-Secret (same shared secret as cron-tick). Body: ignored.
// Optional ?limit=N (default 25, max 100).
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_TICK_SECRET,
//   RAZORPAYX_KEY_ID, RAZORPAYX_KEY_SECRET,
//   RAZORPAYX_ACCOUNT_NUMBER (the RazorpayX virtual current account
//     to debit — found at razorpay.com -> RazorpayX -> Account Details).
//   RAZORPAYX_MODE (optional; "test" or "live", default "live")
//
// SAFETY: if any RAZORPAYX_* var is missing the function logs a
// "not configured" line and returns {ok:true, configured:false,
// processed:0}. This matches the pre-RazorpayX-activation state —
// rows accumulate at status='queued' exactly as they do today, just
// observable via the queue.

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
  razorpay_contact_id: string | null;
  razorpay_fund_account_id: string | null;
  job_number: string;
};

type DispatchResult = {
  payout_id: string;
  outcome: "processing" | "failed" | "no_method" | "skipped";
  reason?: string;
  razorpay_payout_id?: string;
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

  // RazorpayX env check — degrade gracefully when not configured.
  const rzpKeyId = Deno.env.get("RAZORPAYX_KEY_ID");
  const rzpKeySecret = Deno.env.get("RAZORPAYX_KEY_SECRET");
  const rzpAccountNumber = Deno.env.get("RAZORPAYX_ACCOUNT_NUMBER");
  if (!rzpKeyId || !rzpKeySecret || !rzpAccountNumber) {
    console.log("process-engineer-payouts: RAZORPAYX_* not configured, skipping");
    return json(200, { ok: true, configured: false, processed: 0 });
  }
  const rzpAuth = "Basic " + btoa(`${rzpKeyId}:${rzpKeySecret}`);

  const pickRes = await admin.rpc("pick_engineer_payouts_for_processing", { p_limit: limit });
  if (pickRes.error) {
    console.error("pick rpc failed", pickRes.error);
    return json(500, { ok: false, code: "pick_failed", message: pickRes.error.message });
  }
  const picked: PickedRow[] = (pickRes.data as PickedRow[] | null) ?? [];
  if (picked.length === 0) {
    return json(200, { ok: true, configured: true, processed: 0 });
  }

  const results: DispatchResult[] = [];
  for (const row of picked) {
    try {
      results.push(await processOne(admin, row, rzpAuth, rzpAccountNumber));
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
    skipped: results.filter((r) => r.outcome === "skipped").length,
  };
  return json(200, { ok: true, configured: true, processed: picked.length, counts, results });
});

async function processOne(
  admin: SupabaseClient,
  row: PickedRow,
  rzpAuth: string,
  accountNumber: string,
): Promise<DispatchResult> {
  if (!row.method_id || !row.method_kind) {
    await admin.rpc("record_engineer_payout_dispatch", {
      p_payout_id: row.payout_id,
      p_status: "no_method",
    });
    return { payout_id: row.payout_id, outcome: "no_method" };
  }

  // Ensure contact_id.
  let contactId = row.razorpay_contact_id;
  if (!contactId) {
    contactId = await rzpCreateContact(rzpAuth, row);
  }

  // Ensure fund_account_id.
  let fundAccountId = row.razorpay_fund_account_id;
  if (!fundAccountId) {
    fundAccountId = await rzpCreateFundAccount(rzpAuth, row, contactId);
  }

  // Idempotent payout — use our internal payout_id as the Razorpay
  // reference_id so retries of this same row collapse to one charge.
  const payoutResp = await fetch("https://api.razorpay.com/v1/payouts", {
    method: "POST",
    headers: {
      "Authorization": rzpAuth,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      account_number: accountNumber,
      fund_account_id: fundAccountId,
      amount: row.amount_paise,
      currency: "INR",
      mode: row.method_kind === "upi" ? "UPI" : "IMPS",
      purpose: "payout",
      queue_if_low_balance: true,
      reference_id: row.payout_id,
      narration: `EquipSeva ${row.job_number}`.slice(0, 30),
    }),
  });

  const payoutBody = await payoutResp.json().catch(() => ({}));
  if (!payoutResp.ok) {
    const errMsg = (payoutBody as { error?: { description?: string; reason?: string } })
      ?.error?.description ?? `RazorpayX ${payoutResp.status}`;
    await admin.rpc("record_engineer_payout_dispatch", {
      p_payout_id: row.payout_id,
      p_status: "failed",
      p_failure_reason: errMsg.slice(0, 240),
      p_razorpay_contact_id: contactId,
      p_razorpay_fund_account_id: fundAccountId,
    });
    return { payout_id: row.payout_id, outcome: "failed", reason: errMsg };
  }

  const payoutId = (payoutBody as { id?: string })?.id ?? null;
  const status = (payoutBody as { status?: string })?.status ?? "processing";
  await admin.rpc("record_engineer_payout_dispatch", {
    p_payout_id: row.payout_id,
    p_status: "processing",
    p_razorpay_payout_id: payoutId,
    p_razorpayx_status: status,
    p_razorpay_contact_id: contactId,
    p_razorpay_fund_account_id: fundAccountId,
  });
  return {
    payout_id: row.payout_id,
    outcome: "processing",
    razorpay_payout_id: payoutId ?? undefined,
  };
}

async function rzpCreateContact(rzpAuth: string, row: PickedRow): Promise<string> {
  const name = row.method_kind === "upi"
    ? (row.vpa ?? "engineer")
    : (row.bank_account_holder ?? "engineer");
  const resp = await fetch("https://api.razorpay.com/v1/contacts", {
    method: "POST",
    headers: { "Authorization": rzpAuth, "content-type": "application/json" },
    body: JSON.stringify({
      name: name.slice(0, 50),
      type: "vendor",
      reference_id: `eng-${row.engineer_user_id}`,
    }),
  });
  const body = await resp.json();
  if (!resp.ok) {
    throw new Error(
      `contact create failed: ${(body as { error?: { description?: string } })?.error?.description ?? resp.status}`,
    );
  }
  return (body as { id: string }).id;
}

async function rzpCreateFundAccount(
  rzpAuth: string,
  row: PickedRow,
  contactId: string,
): Promise<string> {
  let body: Record<string, unknown>;
  if (row.method_kind === "upi") {
    if (!row.vpa) throw new Error("missing vpa");
    body = {
      contact_id: contactId,
      account_type: "vpa",
      vpa: { address: row.vpa },
    };
  } else {
    if (!row.ifsc || !row.account_number_encrypted || !row.bank_account_holder) {
      throw new Error("missing bank fields");
    }
    body = {
      contact_id: contactId,
      account_type: "bank_account",
      bank_account: {
        name: row.bank_account_holder,
        ifsc: row.ifsc,
        account_number: row.account_number_encrypted,
      },
    };
  }

  const resp = await fetch("https://api.razorpay.com/v1/fund_accounts", {
    method: "POST",
    headers: { "Authorization": rzpAuth, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const respBody = await resp.json();
  if (!resp.ok) {
    throw new Error(
      `fund_account create failed: ${(respBody as { error?: { description?: string } })?.error?.description ?? resp.status}`,
    );
  }
  return (respBody as { id: string }).id;
}
