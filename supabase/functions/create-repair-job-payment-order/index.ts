// Supabase edge function: create-repair-job-payment-order
//
// v2.1 PR-D5 — Razorpay order creation for the per-job escrow pay-in
// (T1.1). Pairs with verify-repair-job-payment. Mirrors the AMC pool
// top-up flow from create-amc-payment-order, but for the per-job
// repair_job_escrow row inserted at accept_repair_bid time.
//
// Request (POST, JSON, Bearer JWT):
//   { repair_job_id: uuid }
// Response 200:
//   { ok: true, payment_order_id, razorpay_order_id, amount_paise,
//     currency, key_id }

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

  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: { repair_job_id?: string };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const jobId = body.repair_job_id;
  if (!jobId || !UUID_RE.test(jobId)) {
    return bad("bad_request", "repair_job_id invalid");
  }

  const admin = createClient(supabaseUrl, serviceKey);

  // Load the existing escrow row (created at accept_repair_bid). We
  // require status='pending' — re-pay attempts on already-held escrows
  // are rejected here; refunds + retries flow through admin tools.
  const { data: escrow, error: escrowErr } = await admin
    .from("repair_job_escrow")
    .select("id, repair_job_id, hospital_user_id, amount_rupees, status, razorpay_order_id")
    .eq("repair_job_id", jobId)
    .maybeSingle();
  if (escrowErr) return bad("server_error", escrowErr.message, 500);
  if (!escrow) return bad("escrow_not_found", "no escrow on this job — accept a bid first", 404);
  if (escrow.hospital_user_id !== userId) {
    return bad("unauthenticated", "not the hospital on this job", 403);
  }
  if (escrow.status !== "pending") {
    return bad("escrow_not_pending", `escrow status is ${escrow.status}`);
  }

  const amountRupees = Number(escrow.amount_rupees);
  if (!Number.isFinite(amountRupees) || amountRupees <= 0) {
    return bad("amount_mismatch", "escrow amount invalid");
  }
  const amountPaise = Math.round(amountRupees * 100);

  const auth = "Basic " + btoa(`${rzpKeyId}:${rzpSecret}`);
  const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: auth },
    // Receipt = escrow id (uuid 36 chars, fits Razorpay's 40-char cap).
    // Notes carry enough context for ops to trace any disputed payment
    // back to a job + hospital without joining tables.
    body: JSON.stringify({
      amount: amountPaise,
      currency: "INR",
      receipt: escrow.id,
      notes: {
        kind: "repair_job_escrow",
        repair_job_id: jobId,
        escrow_id: escrow.id,
        hospital_user_id: userId,
      },
    }),
  });
  const rzpBody = await rzpRes.text();
  if (!rzpRes.ok) {
    return bad("razorpay_error", rzpBody, 502);
  }
  const rzpOrder = JSON.parse(rzpBody) as {
    id: string;
    amount: number;
    currency: string;
  };

  // Bind the razorpay_order_id back to the escrow row. verify-* uses
  // this to defend against replay (signature valid but for a different
  // order id).
  const { error: bindErr } = await admin
    .from("repair_job_escrow")
    .update({
      razorpay_order_id: rzpOrder.id,
    })
    .eq("id", escrow.id);
  if (bindErr) {
    return bad(
      "server_error",
      `failed to persist razorpay_order_id: ${bindErr.message}`,
      500,
    );
  }

  return json(200, {
    ok: true,
    payment_order_id: escrow.id,
    razorpay_order_id: rzpOrder.id,
    amount_paise: rzpOrder.amount,
    currency: rzpOrder.currency,
    key_id: rzpKeyId,
  });
});
