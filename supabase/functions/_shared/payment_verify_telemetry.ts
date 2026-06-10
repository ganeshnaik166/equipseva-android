// Shared payment-verify telemetry helper.
//
// Round 472 — closes audit 6's deferred HIGH: "no replayable record of
// verify failures for stranded-payment recovery."
//
// All three verify-* edge fns (verify-repair-job-payment, verify-amc-payment,
// verify-razorpay-payment) call recordVerifyEvent() at every return point so
// the payment_verify_events table has a queryable row per attempt + outcome.
//
// The call is fire-and-forget: failures to write to the audit table MUST
// NOT block the response or change the outcome the client sees. We swallow
// errors with a console.error and move on.
//
// CRITICAL: never include the razorpay_signature in the payload. The
// signature is HMAC-bound to (order_id|payment_id) so logging it would
// permit replay-attack inspection later.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export type VerifyOrderKind = "repair_escrow" | "amc" | "spare_part";

export type VerifyOutcome =
  | "success"
  | "idempotent_success"
  | "bad_request"
  | "unauthenticated"
  | "not_owner"
  | "invalid_signature"
  | "server_verify_failed"
  | "order_not_found"
  | "status_race"
  | "amount_mismatch"
  | "server_error"
  | "razorpay_error"
  | "escrow_not_pending";

export interface RecordVerifyEventInput {
  verifyFn: string;
  orderKind: VerifyOrderKind;
  outcome: VerifyOutcome;
  orderId?: string | null;
  razorpayOrderId?: string | null;
  razorpayPaymentId?: string | null;
  signatureProvided?: boolean;
  signatureValid?: boolean | null;
  amountPaise?: number | null;
  errorCode?: string | null;
  errorMessage?: string | null;
  userId?: string | null;
  payload?: Record<string, unknown> | null;
}

/**
 * Fire-and-forget audit log. Returns a promise that resolves when the
 * insert succeeds OR when the failure has been logged. Callers should
 * `void` the result rather than await — the verify-* fn return must not
 * block on the audit insert.
 *
 * Best-effort: if the admin client / RPC call fails (e.g. transient
 * Supabase issue), we console.error and continue. The verify response
 * is still authoritative.
 */
export async function recordVerifyEvent(
  admin: SupabaseClient,
  input: RecordVerifyEventInput,
): Promise<void> {
  try {
    // Strip any accidental razorpay_signature key from payload — defense
    // in depth against a future caller passing the raw body in.
    let sanitizedPayload: Record<string, unknown> | null = null;
    if (input.payload && typeof input.payload === "object") {
      sanitizedPayload = { ...input.payload };
      if ("razorpay_signature" in sanitizedPayload) {
        delete sanitizedPayload["razorpay_signature"];
      }
    }

    const { error } = await admin.rpc("record_payment_verify_event", {
      p_verify_fn: input.verifyFn,
      p_order_kind: input.orderKind,
      p_outcome: input.outcome,
      p_order_id: input.orderId ?? null,
      p_razorpay_order_id: input.razorpayOrderId ?? null,
      p_razorpay_payment_id: input.razorpayPaymentId ?? null,
      p_signature_provided: input.signatureProvided ?? false,
      p_signature_valid: input.signatureValid ?? null,
      p_amount_paise: input.amountPaise ?? null,
      p_error_code: input.errorCode ?? null,
      p_error_message: input.errorMessage ?? null,
      p_user_id: input.userId ?? null,
      p_payload: sanitizedPayload,
    });

    if (error) {
      console.error(
        "recordVerifyEvent: RPC failed (telemetry only, response unchanged)",
        input.verifyFn,
        input.outcome,
        error.message,
      );
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(
      "recordVerifyEvent: threw (telemetry only, response unchanged)",
      input.verifyFn,
      input.outcome,
      msg,
    );
  }
}

/**
 * Convenience: build a service-role client for telemetry writes.
 * Verify-* fns already have one; this is for paths that need to record
 * BEFORE they create their admin client (e.g. early auth failures).
 *
 * Returns null if env not set — caller should skip telemetry in that
 * case (we already returned a 500 to the client).
 */
export function makeAdminClientForTelemetry(): SupabaseClient | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  return createClient(url, key);
}
