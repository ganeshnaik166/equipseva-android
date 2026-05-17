// Supabase edge function: verify-amc-payment
//
// Mirrors verify-razorpay-payment (spare-part flow) but for AMC pool
// top-ups. Verifies the Razorpay HMAC signature, marks the
// amc_payment_orders row 'paid', then calls apply_amc_pool_credit RPC
// to insert the ledger credit + resume the contract if it was paused.
//
// Required env (provided by Supabase):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
//
// Request body:
//   { payment_order_id: uuid, razorpay_order_id: string,
//     razorpay_payment_id: string, razorpay_signature: string }
//
// Response 200:
//   { ok: true, payment_order_id, ledger_id, balance_after,
//     contract_status, idempotent? }
//
// Errors: 400 bad_request / invalid_signature, 401 unauthenticated,
// 403 not owner, 404 order_not_found, 500 server_error.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type VerifyBody = {
  payment_order_id?: string;
  razorpay_order_id?: string;
  razorpay_payment_id?: string;
  razorpay_signature?: string;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const RAZORPAY_ID_RE = /^[A-Za-z0-9_]{8,48}$/;

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthenticated", "missing bearer token", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const razorpaySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!supabaseUrl || !anonKey || !serviceKey || !razorpaySecret) {
    return bad("server_error", "edge function not configured", 500);
  }

  // Identity-only client for getUser — never mixed with service-role key.
  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: VerifyBody;
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const { payment_order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature } = body;
  if (!payment_order_id || !UUID_RE.test(payment_order_id)) {
    return bad("bad_request", "payment_order_id invalid");
  }
  if (!razorpay_order_id || !RAZORPAY_ID_RE.test(razorpay_order_id)) {
    return bad("bad_request", "razorpay_order_id invalid");
  }
  if (!razorpay_payment_id || !RAZORPAY_ID_RE.test(razorpay_payment_id)) {
    return bad("bad_request", "razorpay_payment_id invalid");
  }
  if (!razorpay_signature || !/^[a-f0-9]{64}$/i.test(razorpay_signature)) {
    return bad("bad_request", "razorpay_signature invalid");
  }

  // Signature spec: HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, key_secret)
  const expected = await hmacSha256Hex(
    razorpaySecret,
    `${razorpay_order_id}|${razorpay_payment_id}`,
  );
  if (!timingSafeEqualHex(expected, razorpay_signature.toLowerCase())) {
    return bad("invalid_signature", "signature mismatch");
  }

  // service-role client bypasses RLS; we gate ownership ourselves via
  // the join through amc_contracts.hospital_user_id.
  const admin = createClient(supabaseUrl, serviceKey);

  const { data: order, error: fetchErr } = await admin
    .from("amc_payment_orders")
    .select(
      "id, amc_contract_id, status, razorpay_order_id, razorpay_payment_id, amount_rupees, " +
        "amc_contracts!inner(hospital_user_id, status)",
    )
    .eq("id", payment_order_id)
    .maybeSingle();
  if (fetchErr) {
    console.error("verify-amc-payment order_fetch_failed", fetchErr);
    return bad("server_error", "order_fetch_failed", 500);
  }
  if (!order) return bad("order_not_found", "payment order missing", 404);

  // Supabase-js inlines the joined row as either an object or an
  // array depending on cardinality inference. Normalize to object.
  const contract = Array.isArray((order as Record<string, unknown>).amc_contracts)
    ? ((order as { amc_contracts: { hospital_user_id: string; status: string }[] })
        .amc_contracts[0])
    : ((order as { amc_contracts: { hospital_user_id: string; status: string } })
        .amc_contracts);
  if (!contract || contract.hospital_user_id !== userId) {
    return bad("not_owner", "not the hospital on this contract", 403);
  }

  // Replay-attack guard — require client-submitted razorpay_order_id
  // to match the persisted binding from create-amc-payment-order.
  // Without this, valid signatures from any other AMC top-up by the
  // same hospital would verify against this order id.
  if (!order.razorpay_order_id) {
    return bad(
      "invalid_signature",
      "payment order is not bound to a razorpay order; call create-amc-payment-order first",
    );
  }
  if (order.razorpay_order_id !== razorpay_order_id) {
    return bad("invalid_signature", "razorpay_order_id does not match the order binding");
  }

  // Idempotent happy path: already verified, return the existing ledger.
  if (order.status === "paid") {
    const { data: existingLedger } = await admin
      .from("amc_payment_pool")
      .select("id, balance_after")
      .eq("source_payment_order_id", payment_order_id)
      .eq("ledger_kind", "credit")
      .maybeSingle();
    const { data: latestContract } = await admin
      .from("amc_contracts")
      .select("status")
      .eq("id", order.amc_contract_id)
      .maybeSingle();
    return json(200, {
      ok: true,
      payment_order_id,
      ledger_id: existingLedger?.id ?? null,
      balance_after: existingLedger?.balance_after ?? null,
      contract_status: latestContract?.status ?? contract.status,
      idempotent: true,
    });
  }

  // Mark order paid before applying credit so the SECDEF RPC sees it.
  const { error: updErr } = await admin
    .from("amc_payment_orders")
    .update({
      status: "paid",
      razorpay_payment_id,
      updated_at: new Date().toISOString(),
    })
    .eq("id", payment_order_id);
  if (updErr) {
    console.error("verify-amc-payment order_update_failed", updErr);
    return bad("server_error", "order_update_failed", 500);
  }

  const { data: ledgerId, error: rpcErr } = await admin.rpc(
    "apply_amc_pool_credit",
    { p_payment_order_id: payment_order_id },
  );
  if (rpcErr) {
    // Round 306 — don't echo raw postgres error; it can leak constraint
    // names + internal column hints. Same theme as rounds 269–273, 282, 293.
    console.error("verify-amc-payment apply_amc_pool_credit_failed", rpcErr);
    return bad("server_error", "apply_amc_pool_credit_failed", 500);
  }

  // Re-read the freshly inserted ledger row + contract status for the
  // response. Cheap; both are point lookups.
  const { data: ledgerRow } = await admin
    .from("amc_payment_pool")
    .select("balance_after")
    .eq("id", ledgerId)
    .maybeSingle();
  const { data: latestContract } = await admin
    .from("amc_contracts")
    .select("status")
    .eq("id", order.amc_contract_id)
    .maybeSingle();

  return json(200, {
    ok: true,
    payment_order_id,
    ledger_id: ledgerId,
    balance_after: ledgerRow?.balance_after ?? null,
    contract_status: latestContract?.status ?? contract.status,
  });
});
