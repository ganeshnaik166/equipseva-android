// Shared Razorpay refund helper.
//
// Round 473 — closes audit 6's last deferred HIGH: "verify-vs-cancel race
// → stranded captured funds, no auto-refund."
//
// Scenario:
//   1. User pays via Razorpay Checkout → Razorpay captures (money debited)
//   2. Before client `verify-*` returns, user closes sheet → app marks order
//      cancelled locally
//   3. payment.captured webhook arrives → razorpay-webhook RPC finds no
//      pending row → outcome 'no_matching_row'
//   4. WITHOUT auto-refund: money sits with merchant; user thinks failed.
//   5. WITH auto-refund (this helper): webhook posts to Razorpay
//      `/v1/payments/{id}/refund` to return the captured amount.
//
// 422 handling (CRITICAL — was a deferred verifier concern from r472):
//   Razorpay returns 422 when:
//     - payment is already refunded (e.g. duplicate webhook delivery)
//     - payment is in a non-refundable state (rare)
//   These are NOT 5xx errors. Returning 5xx to razorpay-webhook would
//   trigger Razorpay's retry storm. We treat 422 as a SUCCESS for
//   idempotency purposes — the goal was "money returned", and a prior
//   refund already returned it.
//
// Amount validation:
//   Caller MUST pass the amount actually captured (from the webhook
//   payload), not a separately-fetched value. The amount is in paise.

export interface RazorpayRefundResult {
  ok: boolean;
  /**
   * The refund id when ok=true. Either a newly-issued refund or `null`
   * if Razorpay returned "already refunded" (no new refund created).
   */
  refundId: string | null;
  /**
   * One of:
   *   "issued"             — fresh refund created
   *   "already_refunded"   — Razorpay 422 with already-refunded subcode
   *   "rejected_422"       — other 422 (non-refundable state)
   *   "http_error"         — non-2xx, non-422
   *   "fetch_threw"        — network / timeout
   */
  outcome:
    | "issued"
    | "already_refunded"
    | "rejected_422"
    | "http_error"
    | "fetch_threw";
  httpStatus: number | null;
  errorCode: string | null;
  errorMessage: string | null;
}

/**
 * Attempt a full refund against a Razorpay payment.
 *
 * The amount param is the FULL captured amount in paise. We never partial-
 * refund in the auto-refund flow — if the order was cancelled, the entire
 * payment must return.
 *
 * Idempotency: this function is NOT idempotent on its own — Razorpay will
 * create a SECOND refund if you call it twice for the same payment. The
 * caller (razorpay-webhook) MUST gate via razorpay_webhook_events to
 * avoid double-firing.
 *
 * 15-second timeout matches the sibling Razorpay calls in create-*-order.
 */
export async function attemptRazorpayRefund(args: {
  paymentId: string;
  amountPaise: number;
  keyId: string;
  keySecret: string;
  /**
   * Razorpay supports an idempotency key (X-Payment-Idempotency-Key)
   * for refund creation. Pass the razorpay_event_id from the webhook
   * so a replayed webhook hits the same Razorpay-side idempotency key
   * → Razorpay returns the SAME refund row instead of creating a new
   * one. Optional but strongly recommended.
   */
  idempotencyKey?: string;
}): Promise<RazorpayRefundResult> {
  const { paymentId, amountPaise, keyId, keySecret, idempotencyKey } = args;

  if (!paymentId || !paymentId.startsWith("pay_")) {
    return {
      ok: false,
      refundId: null,
      outcome: "http_error",
      httpStatus: null,
      errorCode: "invalid_payment_id",
      errorMessage: "payment id missing or malformed",
    };
  }
  if (!Number.isFinite(amountPaise) || amountPaise <= 0) {
    return {
      ok: false,
      refundId: null,
      outcome: "http_error",
      httpStatus: null,
      errorCode: "invalid_amount",
      errorMessage: "amount must be positive integer paise",
    };
  }

  const auth = "Basic " + btoa(`${keyId}:${keySecret}`);
  const headers: Record<string, string> = {
    "content-type": "application/json",
    authorization: auth,
  };
  if (idempotencyKey) {
    // Razorpay's documented header for refund idempotency.
    headers["X-Payment-Idempotency-Key"] = idempotencyKey;
  }

  let res: Response;
  try {
    res = await fetch(
      `https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}/refund`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          amount: Math.round(amountPaise),
          speed: "optimum",
          notes: {
            reason: "auto_refund_for_cancelled_order_round_473",
          },
        }),
        signal: AbortSignal.timeout(15_000),
      },
    );
  } catch (e) {
    return {
      ok: false,
      refundId: null,
      outcome: "fetch_threw",
      httpStatus: null,
      errorCode: "fetch_threw",
      errorMessage: e instanceof Error ? e.message : String(e),
    };
  }

  const bodyText = await res.text();
  // Razorpay's error envelope:
  //   { error: { code: "BAD_REQUEST_ERROR", description: "...",
  //              reason: "...", source: "...", step: "..." } }
  let parsed: unknown = null;
  try {
    parsed = JSON.parse(bodyText);
  } catch {
    // Non-JSON body — keep as text in errorMessage.
  }

  if (res.ok) {
    // 200 — refund accepted by Razorpay.
    const obj = parsed as { id?: string } | null;
    return {
      ok: true,
      refundId: obj?.id ?? null,
      outcome: "issued",
      httpStatus: res.status,
      errorCode: null,
      errorMessage: null,
    };
  }

  if (res.status === 422) {
    // Inspect the error to distinguish already-refunded from other 422s.
    // Razorpay returns these subcodes (observed in their docs):
    //   - "Payment is already refunded"
    //   - "Refund amount cannot be greater than the captured amount"
    //   - "Payment is not in capture state"
    const err =
      (parsed as { error?: { code?: string; description?: string; reason?: string } } | null)
        ?.error ?? null;
    const description = (err?.description ?? "").toLowerCase();
    const isAlreadyRefunded =
      description.includes("already refunded") ||
      description.includes("already been refunded") ||
      description.includes("fully refunded");

    if (isAlreadyRefunded) {
      // Treat as success — money already returned. This is the
      // idempotency path on duplicate webhook delivery.
      return {
        ok: true,
        refundId: null,
        outcome: "already_refunded",
        httpStatus: 422,
        errorCode: err?.code ?? "ALREADY_REFUNDED",
        errorMessage: err?.description ?? "payment already refunded",
      };
    }

    return {
      ok: false,
      refundId: null,
      outcome: "rejected_422",
      httpStatus: 422,
      errorCode: err?.code ?? "RAZORPAY_422",
      errorMessage: err?.description ?? bodyText.slice(0, 400),
    };
  }

  // Other non-2xx (401, 5xx, etc.) — return as failure so caller can
  // log + alert ops. Razorpay-webhook should return 200 to Razorpay
  // anyway to avoid retry storm; it'll log the auto-refund failure
  // separately for triage.
  const err =
    (parsed as { error?: { code?: string; description?: string } } | null)?.error ?? null;
  return {
    ok: false,
    refundId: null,
    outcome: "http_error",
    httpStatus: res.status,
    errorCode: err?.code ?? `HTTP_${res.status}`,
    errorMessage: err?.description ?? bodyText.slice(0, 400),
  };
}
