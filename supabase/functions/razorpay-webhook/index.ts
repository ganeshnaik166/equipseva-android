// Supabase edge function: razorpay-webhook
//
// Round 471 — Razorpay incoming-payment webhook receiver. Closes the
// audit-6 deferred CRITICAL: verify-fn 5xx after Razorpay captures = no
// automated recovery. This is the parallel handler that fires on every
// Razorpay event regardless of whether the client called verify-*.
//
// Auth:
//   Razorpay signs every webhook with HMAC-SHA256 of the raw body using a
//   per-webhook secret (configured in Razorpay dashboard → Webhooks →
//   Edit → Secret). We verify via X-Razorpay-Signature header using
//   timing-safe compare. Without a valid signature: 401.
//
// Setup (one-time, founder-side):
//   1. supabase secrets set RAZORPAY_WEBHOOK_SECRET="<your-webhook-secret>"
//   2. Razorpay dashboard → Settings → Webhooks → Create New
//      URL: https://eyswaywvtartpvtoxtdr.functions.supabase.co/razorpay-webhook
//      Secret: same value as RAZORPAY_WEBHOOK_SECRET
//      Events: payment.captured, payment.authorized, refund.created, refund.processed
//
// Events handled:
//   payment.captured  → record_razorpay_payment_captured RPC (flips row to held/completed/paid)
//   payment.authorized → same (some flows auto-capture later via Razorpay; we accept either)
//   refund.created    → log only (refund initiated but money not moved yet)
//   refund.processed  → record_razorpay_refund RPC (flips matched row to refunded)
//   anything else     → logged + ignored (200 to Razorpay so they don't retry)
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RAZORPAY_WEBHOOK_SECRET

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { attemptRazorpayRefund } from "../_shared/razorpay_refund.ts";

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

function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

interface RazorpayWebhookEnvelope {
  entity?: string;
  event?: string;
  // Razorpay nests the actual entities under payload.<entity_name>.entity
  payload?: {
    payment?: { entity?: RazorpayPaymentEntity };
    refund?: { entity?: RazorpayRefundEntity };
  };
  created_at?: number;
}

interface RazorpayPaymentEntity {
  id?: string;
  order_id?: string;
  amount?: number;
  currency?: string;
  status?: string;
  method?: string;
}

interface RazorpayRefundEntity {
  id?: string;
  payment_id?: string;
  amount?: number;
  status?: string;
  notes?: Record<string, string>;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return json(405, { ok: false, code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, code: "server_error", message: "edge fn not configured" });
  }
  if (!webhookSecret) {
    // Razorpay will keep retrying until we 200. Fail open with 500 so
    // they don't think we ACK'd; founder needs to set the secret.
    console.error("razorpay-webhook: RAZORPAY_WEBHOOK_SECRET not set — rejecting until configured");
    return json(500, { ok: false, code: "webhook_secret_not_configured" });
  }

  // CRITICAL: read raw body BEFORE parsing JSON — Razorpay signs the
  // exact byte string, and any reformatting (esp. key reordering) breaks
  // the HMAC verify.
  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  const eventId = req.headers.get("x-razorpay-event-id") ?? "";
  if (!signature) {
    return json(401, { ok: false, code: "missing_signature" });
  }
  if (!eventId) {
    // Razorpay always sets this header on production webhooks. Defensive
    // — without it we can't dedup, so reject rather than risk double-fire.
    return json(400, { ok: false, code: "missing_event_id" });
  }

  const expectedSig = await hmacSha256Hex(webhookSecret, rawBody);
  if (!timingSafeEqualHex(expectedSig, signature.toLowerCase())) {
    console.warn("razorpay-webhook: signature mismatch", eventId);
    return json(401, { ok: false, code: "invalid_signature" });
  }

  let envelope: RazorpayWebhookEnvelope;
  try {
    envelope = JSON.parse(rawBody);
  } catch {
    return json(400, { ok: false, code: "invalid_json" });
  }

  const eventType = envelope.event ?? "";
  if (!eventType) {
    return json(400, { ok: false, code: "missing_event_type" });
  }

  const admin = createClient(supabaseUrl, serviceKey);

  try {
    if (eventType === "payment.captured" || eventType === "payment.authorized") {
      const payment = envelope.payload?.payment?.entity;
      const orderId = payment?.order_id ?? "";
      const paymentId = payment?.id ?? "";
      const amount = payment?.amount;
      const currency = payment?.currency ?? "INR";
      if (!orderId || !paymentId || amount == null) {
        console.warn("razorpay-webhook: payment event missing fields", eventId, eventType);
        return json(400, { ok: false, code: "payment_event_missing_fields" });
      }
      const { data, error } = await admin.rpc("record_razorpay_payment_captured", {
        p_razorpay_event_id: eventId,
        p_event_type: eventType,
        p_razorpay_order_id: orderId,
        p_razorpay_payment_id: paymentId,
        p_amount_paise: amount,
        p_currency: currency,
        p_payload: envelope,
      });
      if (error) {
        console.error("razorpay-webhook: record_razorpay_payment_captured failed", eventId, error.message);
        return json(500, { ok: false, code: "rpc_failed", message: "logged for retry" });
      }

      // Round 473 — verify-vs-cancel race auto-refund.
      //
      // If the RPC found no pending row to match (apply_outcome ===
      // 'no_matching_row'), the order may have been cancelled locally
      // between Razorpay capture and webhook delivery. Check all 3
      // intake tables for a matching row in a terminal-cancelled state;
      // if found, auto-refund.
      //
      // Idempotency:
      //   - The RPC's UNIQUE on razorpay_event_id means a replayed
      //     webhook with the same event id returns `data.replayed=true`
      //     and `apply_outcome` is absent → this branch is naturally
      //     skipped on replay.
      //   - We pass eventId as Razorpay's X-Payment-Idempotency-Key so
      //     even cross-event-id retries against the same payment hit
      //     the SAME refund row on Razorpay's side instead of issuing
      //     a duplicate.
      //
      // We NEVER return 5xx from the auto-refund path — Razorpay would
      // retry the webhook and double-fire. Failures are logged + the
      // webhook event audit row carries a triage outcome.
      const outcome = (data as { apply_outcome?: string } | null)?.apply_outcome ?? "";
      if (outcome === "no_matching_row") {
        const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID");
        const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET");

        // Check the 3 intake tables for a matching cancelled row.
        // We use Promise.all because each is an independent point lookup.
        const [escrowQ, spareQ, amcQ] = await Promise.all([
          admin
            .from("repair_job_escrow")
            .select("id, status")
            .eq("razorpay_order_id", orderId)
            .in("status", ["cancelled", "refunded"])
            .maybeSingle(),
          admin
            .from("spare_part_orders")
            .select("id, payment_status, order_status")
            .eq("razorpay_order_id", orderId)
            .or("payment_status.eq.refunded,order_status.eq.cancelled")
            .maybeSingle(),
          admin
            .from("amc_payment_orders")
            .select("id, status")
            .eq("razorpay_order_id", orderId)
            .in("status", ["cancelled", "refunded"])
            .maybeSingle(),
        ]);

        // If any lookup hit a DB error, we don't know whether a
        // cancelled row exists — refusing to refund would strand the
        // payment; firing the refund without checking would risk
        // double-refunding a valid in-flight order. Safer to record
        // for ops triage + return 200 (so Razorpay doesn't retry into
        // a refund storm) than to guess wrong.
        const lookupError = escrowQ.error || spareQ.error || amcQ.error;
        if (lookupError) {
          console.error(
            "razorpay-webhook: auto-refund intake lookup failed",
            eventId,
            paymentId,
            lookupError.message,
          );
          await admin
            .from("razorpay_webhook_events")
            .update({
              applied: false,
              apply_outcome: "auto_refund_failed",
              apply_error: `intake_lookup_failed:${lookupError.message}`.slice(0, 1000),
            })
            .eq("razorpay_event_id", eventId);
          return json(200, {
            ok: false,
            code: "auto_refund_failed",
            applied: data,
          });
        }

        const cancelledRow =
          escrowQ.data || spareQ.data || amcQ.data;

        if (cancelledRow) {
          if (!razorpayKeyId || !razorpayKeySecret) {
            // Can't refund without creds; log + return 200 so Razorpay
            // doesn't retry. Ops will see the orphan in
            // founder_razorpay_webhook_orphans() and manually refund.
            console.error(
              "razorpay-webhook: auto-refund needed but Razorpay creds missing",
              eventId,
              paymentId,
            );
            await admin
              .from("razorpay_webhook_events")
              .update({
                applied: false,
                apply_outcome: "auto_refund_needed_no_creds",
                apply_error: "RAZORPAY_KEY_ID/SECRET env not set",
              })
              .eq("razorpay_event_id", eventId);
            return json(200, {
              ok: false,
              code: "auto_refund_needed_no_creds",
              applied: data,
            });
          }

          console.warn(
            "razorpay-webhook: cancelled order detected, triggering auto-refund",
            eventId,
            orderId,
            paymentId,
            "amount",
            amount,
          );

          const refundResult = await attemptRazorpayRefund({
            paymentId,
            amountPaise: amount,
            keyId: razorpayKeyId,
            keySecret: razorpayKeySecret,
            idempotencyKey: eventId,
          });

          if (refundResult.ok) {
            // Either fresh refund issued OR already-refunded (Razorpay
            // 422 with already-refunded subcode → treated as success).
            await admin
              .from("razorpay_webhook_events")
              .update({
                applied: true,
                apply_outcome:
                  refundResult.outcome === "already_refunded"
                    ? "auto_refund_already_refunded"
                    : "auto_refund_issued",
                razorpay_refund_id: refundResult.refundId,
              })
              .eq("razorpay_event_id", eventId);
            return json(200, {
              ok: true,
              applied: data,
              auto_refund: {
                outcome: refundResult.outcome,
                refund_id: refundResult.refundId,
              },
            });
          }

          // Refund attempt failed (non-2xx, non-422-already-refunded,
          // or network error). Log for triage but STILL return 200 so
          // Razorpay doesn't retry the webhook into a refund storm.
          // Ops queries founder_razorpay_webhook_orphans() to find
          // these and follow up manually.
          console.error(
            "razorpay-webhook: auto-refund attempt failed",
            eventId,
            paymentId,
            refundResult.outcome,
            refundResult.httpStatus,
            refundResult.errorCode,
            refundResult.errorMessage,
          );
          await admin
            .from("razorpay_webhook_events")
            .update({
              applied: false,
              apply_outcome: "auto_refund_failed",
              apply_error: `${refundResult.outcome}:${refundResult.errorCode ?? "unknown"}:${refundResult.errorMessage ?? ""}`.slice(0, 1000),
            })
            .eq("razorpay_event_id", eventId);
          return json(200, {
            ok: false,
            code: "auto_refund_failed",
            applied: data,
            auto_refund: {
              outcome: refundResult.outcome,
              http_status: refundResult.httpStatus,
              error_code: refundResult.errorCode,
            },
          });
        }
        // no_matching_row but also no cancelled row found — could be
        // a race where create-* hasn't committed yet, or a real orphan.
        // Leave as-is; ops will see in founder_razorpay_webhook_orphans.
      }

      return json(200, { ok: true, applied: data });
    }

    if (eventType === "refund.created" || eventType === "refund.processed") {
      const refund = envelope.payload?.refund?.entity;
      const refundId = refund?.id ?? "";
      const paymentId = refund?.payment_id ?? "";
      const amount = refund?.amount;
      // Razorpay's refund event payload doesn't always echo order_id;
      // we resolve it from payment_id in the RPC if missing.
      const orderId = envelope.payload?.payment?.entity?.order_id ?? "";
      if (!refundId || !paymentId || amount == null) {
        console.warn("razorpay-webhook: refund event missing fields", eventId, eventType);
        return json(400, { ok: false, code: "refund_event_missing_fields" });
      }
      const { data, error } = await admin.rpc("record_razorpay_refund", {
        p_razorpay_event_id: eventId,
        p_event_type: eventType,
        p_razorpay_refund_id: refundId,
        p_razorpay_payment_id: paymentId,
        p_razorpay_order_id: orderId,
        p_amount_paise: amount,
        p_payload: envelope,
      });
      if (error) {
        console.error("razorpay-webhook: record_razorpay_refund failed", eventId, error.message);
        return json(500, { ok: false, code: "rpc_failed", message: "logged for retry" });
      }
      return json(200, { ok: true, applied: data });
    }

    // Any other event type — log to the audit table (without side effects)
    // and return 200 so Razorpay doesn't retry. We can replay manually
    // from the audit table later if needed.
    await admin.from("razorpay_webhook_events")
      .insert({
        razorpay_event_id: eventId,
        event_type: eventType,
        payload: envelope,
        applied: false,
        apply_outcome: "unhandled_event_type",
      })
      .select()
      .single()
      .then((r) => {
        if (r.error && !/duplicate/i.test(r.error.message)) {
          console.error("razorpay-webhook: log unhandled failed", r.error.message);
        }
      });
    return json(200, { ok: true, applied: false, code: "unhandled_event_type" });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("razorpay-webhook: handler threw", eventId, eventType, msg);
    return json(500, { ok: false, code: "handler_threw", message: msg.slice(0, 200) });
  }
});
