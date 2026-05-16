// Supabase edge function: create-amc-payment-order
//
// Creates a Razorpay order for an AMC pre-paid pool top-up. Mirrors
// create-razorpay-order (spare-part flow) so we can re-use the same
// HMAC-verify replay-attack guard in verify-amc-payment.
//
// Request (POST, JSON, Bearer JWT):
//   { amc_contract_id: uuid, months: int }
//
// Response 200:
//   { ok: true, payment_order_id, razorpay_order_id, amount_paise,
//     currency, key_id }
//
// Errors: 400 bad_request / amount_mismatch / contract_inactive,
// 401 unauthenticated, 403 not owner, 404 contract_not_found,
// 502 razorpay_error, 500 server_error.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthenticated", "missing bearer token", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const rzpKeyId = Deno.env.get("RAZORPAY_KEY_ID");
  const rzpSecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!supabaseUrl || !anonKey || !serviceKey || !rzpKeyId || !rzpSecret) {
    return bad("server_error", "edge function not configured", 500);
  }

  // Identity decode under the caller's role only. Same envelope as
  // create-razorpay-order: an anon-key client carrying the bearer
  // header. We never mix the service key with the caller's JWT on the
  // same client (defense against any future supabase-js precedence
  // change silently elevating the caller).
  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: { amc_contract_id?: string; months?: number };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const contractId = body.amc_contract_id;
  const months = Number(body.months);
  if (!contractId || !UUID_RE.test(contractId)) {
    return bad("bad_request", "amc_contract_id invalid");
  }
  if (!Number.isInteger(months) || months < 1 || months > 36) {
    return bad("bad_request", "months must be int 1..36");
  }

  // Service-role client for writes; we gate ownership ourselves
  // before touching anything.
  const admin = createClient(supabaseUrl, serviceKey);

  const { data: contract, error: fetchErr } = await admin
    .from("amc_contracts")
    .select("id, hospital_user_id, status, monthly_fee_rupees")
    .eq("id", contractId)
    .maybeSingle();
  if (fetchErr) {
    console.error("create-amc-payment-order contract_fetch_failed", fetchErr);
    return bad("server_error", "contract_fetch_failed", 500);
  }
  if (!contract) return bad("contract_not_found", "amc contract missing", 404);
  if (contract.hospital_user_id !== userId) {
    return bad("unauthenticated", "not owner", 403);
  }
  // Refuse to charge contracts that can never accept new credit usefully.
  if (
    contract.status === "cancelled" ||
    contract.status === "expired" ||
    contract.status === "renewal_failed"
  ) {
    return bad("contract_inactive", `contract status is ${contract.status}`);
  }

  const monthlyFee = Number(contract.monthly_fee_rupees);
  if (!Number.isFinite(monthlyFee) || monthlyFee <= 0) {
    return bad("amount_mismatch", "monthly_fee invalid");
  }
  const amountRupees = Math.round(monthlyFee * months * 100) / 100;
  const amountPaise = Math.round(amountRupees * 100);
  if (!Number.isFinite(amountPaise) || amountPaise <= 0) {
    return bad("amount_mismatch", "computed amount invalid");
  }

  // Dedup: if a recent pending+bound order already exists for the same
  // (contract, months) at the same amount, reuse it. Prevents the
  // double-tap pile-up where every fast retry leaves another stale
  // 'pending' row in the table. We don't touch unbound rows (where
  // razorpay_order_id is still null) — those represent an in-flight
  // create call from another concurrent attempt that may yet finish.
  const dedupCutoff = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const { data: existingOrder } = await admin
    .from("amc_payment_orders")
    .select("id, razorpay_order_id, amount_rupees")
    .eq("amc_contract_id", contractId)
    .eq("months_paid", months)
    .eq("status", "pending")
    .not("razorpay_order_id", "is", null)
    .gte("created_at", dedupCutoff)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingOrder?.razorpay_order_id) {
    const existingPaise = Math.round(Number(existingOrder.amount_rupees) * 100);
    if (existingPaise === amountPaise) {
      return json(200, {
        ok: true,
        payment_order_id: existingOrder.id,
        razorpay_order_id: existingOrder.razorpay_order_id,
        amount_paise: amountPaise,
        currency: "INR",
        key_id: rzpKeyId,
        deduped: true,
      });
    }
  }

  // Persist the order row first so we have an id for receipt + notes.
  const { data: insertedOrder, error: insertErr } = await admin
    .from("amc_payment_orders")
    .insert({
      amc_contract_id: contractId,
      months_paid: months,
      amount_rupees: amountRupees,
      status: "pending",
    })
    .select("id")
    .single();
  if (insertErr || !insertedOrder) {
    return bad("server_error", insertErr?.message ?? "insert failed", 500);
  }
  const paymentOrderId = insertedOrder.id;

  // Create Razorpay order. receipt is our payment_order id (max 40
  // chars on Razorpay; uuid is 36 — fits). Notes carry just enough
  // context that ops can trace any disputed payment back to a
  // contract + hospital without joining tables.
  const auth = "Basic " + btoa(`${rzpKeyId}:${rzpSecret}`);
  // Razorpay's /orders endpoint usually responds in ~200ms but has
  // tail latency spikes; cap the wait at 15s so a hung upstream
  // doesn't starve the function's 300s execution budget (and the
  // client's already-displayed spinner).
  const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: auth },
    body: JSON.stringify({
      amount: amountPaise,
      currency: "INR",
      receipt: paymentOrderId,
      notes: {
        kind: "amc_pool_topup",
        amc_contract_id: contractId,
        payment_order_id: paymentOrderId,
        hospital_user_id: userId,
        months: String(months),
      },
    }),
    signal: AbortSignal.timeout(15_000),
  });
  const rzpBody = await rzpRes.text();
  if (!rzpRes.ok) {
    // Mark our order failed so a retry creates a fresh one — easier
    // than reusing a half-bound row.
    await admin
      .from("amc_payment_orders")
      .update({ status: "failed", updated_at: new Date().toISOString() })
      .eq("id", paymentOrderId);
    // Don't echo Razorpay error body to the client OR the full
    // payload to logs — Razorpay returns merchant-account codes /
    // internal retry hints we don't want shipped to semi-public
    // Edge Function logs. Truncate to keep just the leading error
    // class (matches create-razorpay-order:108 sanitization).
    console.error(
      "create-amc-payment-order: razorpay non-2xx",
      rzpRes.status,
      rzpBody.slice(0, 400),
    );
    return bad("razorpay_error", "payment provider unavailable", 502);
  }
  const rzpOrder = JSON.parse(rzpBody) as {
    id: string;
    amount: number;
    currency: string;
  };

  const { error: bindErr } = await admin
    .from("amc_payment_orders")
    .update({
      razorpay_order_id: rzpOrder.id,
      updated_at: new Date().toISOString(),
    })
    .eq("id", paymentOrderId);
  if (bindErr) {
    return bad(
      "server_error",
      `failed to persist razorpay_order_id: ${bindErr.message}`,
      500,
    );
  }

  return json(200, {
    ok: true,
    payment_order_id: paymentOrderId,
    razorpay_order_id: rzpOrder.id,
    amount_paise: rzpOrder.amount,
    currency: rzpOrder.currency,
    key_id: rzpKeyId,
  });
});
