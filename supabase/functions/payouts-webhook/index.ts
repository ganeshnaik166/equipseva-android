// Supabase edge function: payouts-webhook
//
// Round 432: receives Cashfree Payouts lifecycle events.
// Replaces the round-424 `razorpayx-webhook` after RazorpayX hard-
// rejected sole proprietorships on 2026-06-03.
//
// Events of interest:
//   TRANSFER_SUCCESS    → flip our row to 'processed' (utr available)
//   TRANSFER_FAILED     → 'failed'
//   TRANSFER_REJECTED   → 'failed'
//   TRANSFER_REVERSED   → 'failed' (recorded with reversed status)
//   TRANSFER_PROCESSING → 'processing' (mirrors internal status)
//   TRANSFER_INITIATED  → 'queued' (echo only)
//
// Signature: Cashfree posts an `x-webhook-signature` header containing
// HMAC-SHA256(rawBody, CASHFREE_WEBHOOK_SECRET) BASE64-encoded.
//
// Configure in Cashfree dashboard → Payouts → Webhooks → URL:
//   https://eyswaywvtartpvtoxtdr.supabase.co/functions/v1/payouts-webhook
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CASHFREE_WEBHOOK_SECRET.
//
// Returns 200 to Cashfree on every parsed event (even on internal
// errors) so Cashfree doesn't retry indefinitely.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

async function hmacSha256Base64(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

function timingSafeEqualStr(a: string, b: string): boolean {
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
  const webhookSecret = Deno.env.get("CASHFREE_WEBHOOK_SECRET");
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, code: "server_error", message: "edge fn not configured" });
  }
  if (!webhookSecret) {
    // Webhook not yet configured — return 200 so Cashfree doesn't
    // retry. The cashfree dashboard's webhook URL is what triggers
    // this; if it's set without the secret env on our side, that's a
    // misconfiguration we want to acknowledge silently.
    console.log("payouts-webhook: CASHFREE_WEBHOOK_SECRET unset, ignoring");
    return json(200, { ok: true, configured: false });
  }

  const raw = await req.text();
  const signature = req.headers.get("x-webhook-signature") ?? "";
  const expected = await hmacSha256Base64(webhookSecret, raw);
  if (!timingSafeEqualStr(signature, expected)) {
    return json(401, { ok: false, code: "bad_signature" });
  }

  let event: {
    event?: string;
    data?: {
      transferId?: string;
      referenceId?: string | number;
      status?: string;
      statusDescription?: string;
      utr?: string;
      transferMode?: string;
      reason?: string;
    };
  };
  try {
    event = JSON.parse(raw);
  } catch {
    return json(400, { ok: false, code: "bad_json" });
  }

  const data = event.data ?? {};
  const refId = data.referenceId != null ? String(data.referenceId) : null;
  if (!refId) {
    return json(200, { ok: true, ignored: "no_reference_id" });
  }

  // Map Cashfree event_kind onto our internal state machine.
  const eventToKind: Record<string, string> = {
    "TRANSFER_SUCCESS": "processed",
    "TRANSFER_FAILED": "failed",
    "TRANSFER_REJECTED": "failed",
    "TRANSFER_REVERSED": "reversed",
    "TRANSFER_PROCESSING": "processing",
    "TRANSFER_INITIATED": "queued",
  };
  const internalKind = eventToKind[event.event ?? ""];
  if (!internalKind) {
    // Not an event type we care about — ack silently.
    return json(200, { ok: true, ignored: event.event ?? "unknown" });
  }

  const failureReason = [data.statusDescription, data.reason]
    .filter(Boolean)
    .join(" — ")
    .slice(0, 240) || null;

  const admin = createClient(supabaseUrl, serviceKey);
  const { error, data: rpcData } = await admin.rpc("record_engineer_payout_webhook", {
    p_razorpay_payout_id: refId,
    p_event_kind: internalKind,
    p_utr: data.utr ?? null,
    p_mode: cashfreeModeToInternal(data.transferMode),
    p_failure_reason: failureReason,
  });
  if (error) {
    console.error("webhook rpc error", refId, error);
    return json(200, { ok: true, error: error.message });
  }
  return json(200, { ok: true, reference_id: refId, kind: internalKind, matched: rpcData });
});

/**
 * Cashfree mode strings vs our column allowlist
 * (UPI / IMPS / NEFT / RTGS — set on the engineer_payouts.mode column).
 */
function cashfreeModeToInternal(cfMode: string | undefined): string | null {
  if (!cfMode) return null;
  const m = cfMode.toLowerCase();
  if (m.includes("upi")) return "UPI";
  if (m.includes("imps")) return "IMPS";
  if (m.includes("neft")) return "NEFT";
  if (m.includes("rtgs")) return "RTGS";
  if (m.includes("bank")) return "IMPS";  // banktransfer maps to IMPS by default
  return null;
}
