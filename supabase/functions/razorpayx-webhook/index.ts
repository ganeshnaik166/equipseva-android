// Supabase edge function: razorpayx-webhook
//
// Round 424. Receives RazorpayX payout lifecycle events:
//   payout.processed | payout.failed | payout.reversed |
//   payout.processing | payout.queued
//
// Verifies the X-Razorpay-Signature header (HMAC-SHA256 over the raw
// body with RAZORPAYX_WEBHOOK_SECRET), then routes the event into
// record_engineer_payout_webhook which flips engineer_payouts.status
// and, on first successful processed event, marks the
// engineer_payout_methods row verified.
//
// Set this URL in razorpay.com -> RazorpayX -> Webhooks. The "active
// events" must include the five above; signature secret must match
// RAZORPAYX_WEBHOOK_SECRET in Supabase env.
//
// Always returns 200 to RazorpayX even on lookups that miss our DB
// (e.g. payouts from a different env). We swallow errors to keep
// RazorpayX from retrying indefinitely and clogging our logs.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

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

function timingSafeHexEq(a: string, b: string): boolean {
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
  const webhookSecret = Deno.env.get("RAZORPAYX_WEBHOOK_SECRET");
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, code: "server_error", message: "edge fn not configured" });
  }
  if (!webhookSecret) {
    // Webhook not yet wired — return 200 so RazorpayX doesn't retry.
    console.log("razorpayx-webhook: RAZORPAYX_WEBHOOK_SECRET unset, ignoring");
    return json(200, { ok: true, configured: false });
  }

  const raw = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  const expected = await hmacSha256Hex(webhookSecret, raw);
  if (!timingSafeHexEq(signature, expected)) {
    return json(401, { ok: false, code: "bad_signature" });
  }

  let event: { event?: string; payload?: { payout?: { entity?: Record<string, unknown> } } };
  try {
    event = JSON.parse(raw);
  } catch {
    return json(400, { ok: false, code: "bad_json" });
  }

  const kind = event.event ?? "";
  const payout = event.payload?.payout?.entity as
    | {
        id?: string;
        status?: string;
        utr?: string;
        mode?: string;
        failure_reason?: string;
      }
    | undefined;
  if (!payout?.id) {
    return json(200, { ok: true, ignored: "no_payout_id" });
  }

  const eventToKind: Record<string, string> = {
    "payout.processed": "processed",
    "payout.failed": "failed",
    "payout.reversed": "reversed",
    "payout.processing": "processing",
    "payout.queued": "queued",
  };
  const internalKind = eventToKind[kind];
  if (!internalKind) {
    // Not an event type we care about (e.g. payout.initiated which
    // is not in our state machine). Acknowledge silently.
    return json(200, { ok: true, ignored: kind });
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const { error, data } = await admin.rpc("record_engineer_payout_webhook", {
    p_razorpay_payout_id: payout.id,
    p_event_kind: internalKind,
    p_utr: payout.utr ?? null,
    p_mode: payout.mode ?? null,
    p_failure_reason: payout.failure_reason ?? null,
  });
  if (error) {
    console.error("webhook rpc error", payout.id, error);
    // Always 200 — see header comment.
    return json(200, { ok: true, error: error.message });
  }
  return json(200, { ok: true, payout_id: payout.id, kind: internalKind, matched: data });
});
