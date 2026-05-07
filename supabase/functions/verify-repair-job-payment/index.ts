// Supabase edge function: verify-repair-job-payment
//
// v2.1 PR-D5 — verifies the Razorpay HMAC signature returned by
// Razorpay Standard Checkout, then flips the per-job escrow row from
// 'pending' to 'held'. Pairs with create-repair-job-payment-order.
//
// Idempotent: if the escrow is already 'held' for the same razorpay
// payment id we return ok+idempotent=true.
//
// Required env: SUPABASE_URL, SUPABASE_ANON_KEY,
// SUPABASE_SERVICE_ROLE_KEY, RAZORPAY_KEY_SECRET.
//
// Request body:
//   { escrow_id: uuid, razorpay_order_id: string,
//     razorpay_payment_id: string, razorpay_signature: string }
// Response 200:
//   { ok: true, escrow_id, status: 'held', idempotent? }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

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

  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: {
    escrow_id?: string;
    razorpay_order_id?: string;
    razorpay_payment_id?: string;
    razorpay_signature?: string;
  };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const { escrow_id, razorpay_order_id, razorpay_payment_id, razorpay_signature } = body;
  if (!escrow_id || !UUID_RE.test(escrow_id)) {
    return bad("bad_request", "escrow_id invalid");
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

  // Razorpay signature spec:
  //   HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, key_secret)
  const expected = await hmacSha256Hex(
    razorpaySecret,
    `${razorpay_order_id}|${razorpay_payment_id}`,
  );
  if (!timingSafeEqualHex(expected, razorpay_signature.toLowerCase())) {
    return bad("invalid_signature", "signature mismatch");
  }

  const admin = createClient(supabaseUrl, serviceKey);

  const { data: escrow, error: fetchErr } = await admin
    .from("repair_job_escrow")
    .select(
      "id, repair_job_id, hospital_user_id, status, razorpay_order_id, razorpay_payment_id",
    )
    .eq("id", escrow_id)
    .maybeSingle();
  if (fetchErr) return bad("server_error", fetchErr.message, 500);
  if (!escrow) return bad("escrow_not_found", "escrow row missing", 404);
  if (escrow.hospital_user_id !== userId) {
    return bad("not_owner", "not the hospital on this escrow", 403);
  }

  // Replay-attack guard. Without this a valid signature on any other
  // pending escrow row by the same hospital would verify here.
  if (!escrow.razorpay_order_id) {
    return bad(
      "invalid_signature",
      "escrow not bound to a razorpay order; call create-repair-job-payment-order first",
    );
  }
  if (escrow.razorpay_order_id !== razorpay_order_id) {
    return bad("invalid_signature", "razorpay_order_id does not match the escrow binding");
  }

  // Idempotent: already paid for the same payment id.
  if (escrow.status === "held" && escrow.razorpay_payment_id === razorpay_payment_id) {
    return json(200, {
      ok: true,
      escrow_id,
      status: "held",
      idempotent: true,
    });
  }
  if (escrow.status !== "pending") {
    return bad("escrow_not_pending", `escrow status is ${escrow.status}`);
  }

  const { error: updErr } = await admin
    .from("repair_job_escrow")
    .update({
      status: "held",
      razorpay_payment_id,
      paid_at: new Date().toISOString(),
    })
    .eq("id", escrow_id);
  if (updErr) return bad("server_error", updErr.message, 500);

  await admin.from("repair_job_escrow_events").insert({
    escrow_id,
    event_kind: "paid",
    actor_user_id: userId,
    payload: {
      razorpay_order_id,
      razorpay_payment_id,
    },
  });

  return json(200, {
    ok: true,
    escrow_id,
    status: "held",
  });
});
