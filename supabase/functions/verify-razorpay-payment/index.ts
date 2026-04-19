// Supabase edge function: verify-razorpay-payment
//
// Called by the Android client (and any other surface) after Razorpay Checkout returns a
// success callback. Verifies the HMAC-SHA256 signature server-side before we trust the
// payment and flip `spare_part_orders.payment_status = 'completed'`.
//
// Required env:
//   RAZORPAY_KEY_ID         — public key id (safe to expose)
//   RAZORPAY_KEY_SECRET     — secret, edge-function only; never sent to clients
//   SUPABASE_URL            — injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY — injected by Supabase; used to bypass RLS for the
//                              payment_status update (RLS denies anon writes to that column).
//
// Request body:
//   { order_id: uuid, razorpay_order_id: string, razorpay_payment_id: string, razorpay_signature: string }
//
// Response:
//   200 { ok: true, order_id, payment_id, payment_status: 'completed', order_status: 'confirmed' }
//   400 { ok: false, code: 'invalid_signature' | 'bad_request' | 'order_not_found' | 'amount_mismatch', message }
//   401 { ok: false, code: 'unauthenticated' }
//   500 { ok: false, code: 'server_error', message }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type VerifyBody = {
  order_id?: string;
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
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const razorpaySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!supabaseUrl || !serviceKey || !razorpaySecret) {
    return bad("server_error", "edge function not configured", 500);
  }

  // Verify the caller's JWT and extract user id. Uses anon-role read-only client
  // since all we need is identity; the subsequent write uses service-role.
  const userClient = createClient(supabaseUrl, serviceKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
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
  const { order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature } = body;
  if (!order_id || !UUID_RE.test(order_id)) return bad("bad_request", "order_id invalid");
  if (!razorpay_order_id || !RAZORPAY_ID_RE.test(razorpay_order_id)) return bad("bad_request", "razorpay_order_id invalid");
  if (!razorpay_payment_id || !RAZORPAY_ID_RE.test(razorpay_payment_id)) return bad("bad_request", "razorpay_payment_id invalid");
  if (!razorpay_signature || !/^[a-f0-9]{64}$/i.test(razorpay_signature)) return bad("bad_request", "razorpay_signature invalid");

  // Signature spec: HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, key_secret)
  // https://razorpay.com/docs/payments/server-integration/node/payment-gateway/build-integration/#16-verify-payment-signature
  const expected = await hmacSha256Hex(razorpaySecret, `${razorpay_order_id}|${razorpay_payment_id}`);
  if (!timingSafeEqualHex(expected, razorpay_signature.toLowerCase())) {
    return bad("invalid_signature", "signature mismatch");
  }

  // service-role client bypasses RLS; we gate ownership ourselves.
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: order, error: fetchErr } = await admin
    .from("spare_part_orders")
    .select("id, buyer_user_id, payment_status, order_status, total_amount")
    .eq("id", order_id)
    .maybeSingle();
  if (fetchErr) return bad("server_error", fetchErr.message, 500);
  if (!order) return bad("order_not_found", "order missing", 404);
  if (order.buyer_user_id !== userId) return bad("unauthenticated", "not owner", 403);

  // Idempotent: if already completed, return the current state.
  if (order.payment_status === "completed") {
    return json(200, {
      ok: true,
      order_id: order.id,
      payment_id: razorpay_payment_id,
      payment_status: "completed",
      order_status: order.order_status ?? "confirmed",
      idempotent: true,
    });
  }

  const { error: updErr } = await admin
    .from("spare_part_orders")
    .update({
      payment_status: "completed",
      order_status: "confirmed",
      payment_id: razorpay_payment_id,
    })
    .eq("id", order_id);
  if (updErr) return bad("server_error", updErr.message, 500);

  return json(200, {
    ok: true,
    order_id,
    payment_id: razorpay_payment_id,
    payment_status: "completed",
    order_status: "confirmed",
  });
});
