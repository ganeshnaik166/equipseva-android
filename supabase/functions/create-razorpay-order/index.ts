// Supabase edge function: create-razorpay-order
//
// Creates a Razorpay order via the Orders API before the client launches Checkout. The
// returned `razorpay_order_id` is then passed into Razorpay Checkout as `order_id`, which
// binds the subsequent success callback to a signed (order_id, payment_id) pair we can
// verify in `verify-razorpay-payment`.
//
// Request (JSON, POST, Bearer JWT):
//   { order_id: uuid }
//
// Response 200:
//   { ok: true, razorpay_order_id, amount, currency }
//
// Errors: 400 bad_request / amount_mismatch, 401 unauthenticated, 403 not owner,
// 404 order_not_found, 502 razorpay_error, 500 server_error.

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

  // Identity check uses an anon-key client carrying the caller's bearer header so
  // the JWT is decoded under the role it was issued for. We deliberately do NOT
  // mix the service-role key with the caller's header — if a future supabase-js
  // changes precedence, that pattern could silently grant service-role identity
  // to any caller with a valid token.
  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: { order_id?: string };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const orderId = body.order_id;
  if (!orderId || !UUID_RE.test(orderId)) return bad("bad_request", "order_id invalid");

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: order, error: fetchErr } = await admin
    .from("spare_part_orders")
    .select("id, buyer_user_id, total_amount, order_number, payment_status")
    .eq("id", orderId)
    .maybeSingle();
  if (fetchErr) return bad("server_error", fetchErr.message, 500);
  if (!order) return bad("order_not_found", "order missing", 404);
  if (order.buyer_user_id !== userId) return bad("unauthenticated", "not owner", 403);
  if (order.payment_status === "completed") {
    return bad("bad_request", "order already paid");
  }

  const amountPaise = Math.round(Number(order.total_amount) * 100);
  if (!Number.isFinite(amountPaise) || amountPaise <= 0) {
    return bad("amount_mismatch", "order total invalid");
  }

  const auth = "Basic " + btoa(`${rzpKeyId}:${rzpSecret}`);
  const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: auth },
    body: JSON.stringify({
      amount: amountPaise,
      currency: "INR",
      receipt: order.order_number ?? order.id,
      notes: { supabase_order_id: order.id, buyer_user_id: userId },
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

  // Persist the Razorpay order id so verify-razorpay-payment can require
  // a match between the client-submitted razorpay_order_id and the one we
  // actually issued. Without this binding, an attacker could replay a
  // signature from a cheaper Razorpay order to complete an expensive
  // Supabase order (same buyer, different amounts).
  const { error: persistErr } = await admin
    .from("spare_part_orders")
    .update({ razorpay_order_id: rzpOrder.id })
    .eq("id", orderId);
  if (persistErr) {
    return bad("server_error", `failed to persist razorpay_order_id: ${persistErr.message}`, 500);
  }

  return json(200, {
    ok: true,
    razorpay_order_id: rzpOrder.id,
    amount: rzpOrder.amount,
    currency: rzpOrder.currency,
  });
});
