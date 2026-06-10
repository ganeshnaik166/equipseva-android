// Shared Razorpay server-side verify helper.
//
// Round 469 — CRITICAL fix from audit 6.
//
// Razorpay's HMAC signature only covers (order_id|payment_id). It does NOT
// prove what amount was actually paid. Without a server-side check, an
// attacker who can mutate the order row's amount AFTER binding razorpay_order_id
// (e.g. via items array on spare_part_orders pre-round-469) can pay the OLD
// amount at Razorpay and have us flip the row to completed at the NEW amount.
//
// This util fetches Razorpay's authoritative GET /v1/payments/{id} endpoint
// and asserts:
//   1. payment.order_id matches the client-claimed razorpay_order_id
//   2. payment.status is one of 'captured' or 'authorized' (allow authorized
//      because auto-capture may have a small delay; webhook will flip when
//      capture lands)
//   3. payment.amount === expected paise (server-computed from the row)
//   4. payment.currency === 'INR'
//
// This is Razorpay's own documented anti-tamper backstop. Their integration
// guide explicitly recommends this in addition to the HMAC verify.

export interface RazorpayPaymentSnapshot {
  id: string;
  order_id: string;
  status: string;
  amount: number; // paise
  currency: string;
}

export interface ServerVerifyResult {
  ok: boolean;
  code?: string;
  message?: string;
  payment?: RazorpayPaymentSnapshot;
}

const RAZORPAY_BASE = "https://api.razorpay.com/v1";

/**
 * Fetch the payment from Razorpay's server-side API and assert it matches
 * the expected order/amount. Returns {ok:true, payment} on match;
 * {ok:false, code, message} otherwise.
 *
 * The caller MUST provide the razorpay key_id + key_secret (Basic Auth).
 * These are env vars (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET) — pass them
 * in explicitly so each edge fn loads its own env.
 */
export async function razorpayServerVerify(opts: {
  keyId: string;
  keySecret: string;
  razorpayPaymentId: string;
  expectedOrderId: string;
  expectedAmountPaise: number;
  expectedCurrency?: string; // default INR
  timeoutMs?: number; // default 8000
}): Promise<ServerVerifyResult> {
  const {
    keyId,
    keySecret,
    razorpayPaymentId,
    expectedOrderId,
    expectedAmountPaise,
    expectedCurrency = "INR",
    timeoutMs = 8_000,
  } = opts;

  if (!keyId || !keySecret) {
    return {
      ok: false,
      code: "razorpay_env_missing",
      message: "RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET not configured",
    };
  }
  if (!razorpayPaymentId) {
    return { ok: false, code: "bad_request", message: "missing razorpay_payment_id" };
  }
  if (!expectedOrderId) {
    return { ok: false, code: "bad_request", message: "missing expected order_id" };
  }

  const basicAuth = btoa(`${keyId}:${keySecret}`);

  let resp: Response;
  try {
    resp = await fetch(`${RAZORPAY_BASE}/payments/${encodeURIComponent(razorpayPaymentId)}`, {
      method: "GET",
      headers: {
        Authorization: `Basic ${basicAuth}`,
        "content-type": "application/json",
      },
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, code: "razorpay_fetch_failed", message: msg };
  }

  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    // 404 → payment doesn't exist (forged client claim)
    // 401 → key mismatch (env wrong)
    // 5xx → Razorpay outage
    return {
      ok: false,
      code: resp.status === 404 ? "payment_not_found" : `razorpay_${resp.status}`,
      message: body.slice(0, 200),
    };
  }

  let body: Partial<RazorpayPaymentSnapshot> & Record<string, unknown>;
  try {
    body = await resp.json();
  } catch {
    return { ok: false, code: "razorpay_bad_json", message: "non-JSON response from Razorpay" };
  }

  const payment: RazorpayPaymentSnapshot = {
    id: String(body.id ?? ""),
    order_id: String(body.order_id ?? ""),
    status: String(body.status ?? ""),
    amount: Number(body.amount ?? 0),
    currency: String(body.currency ?? ""),
  };

  if (payment.id !== razorpayPaymentId) {
    return { ok: false, code: "payment_id_mismatch", message: `id ${payment.id} != ${razorpayPaymentId}`, payment };
  }
  if (payment.order_id !== expectedOrderId) {
    return { ok: false, code: "order_id_mismatch", message: `order_id ${payment.order_id} != ${expectedOrderId}`, payment };
  }
  if (payment.amount !== expectedAmountPaise) {
    return {
      ok: false,
      code: "amount_mismatch",
      message: `Razorpay says ${payment.amount} paise; we expected ${expectedAmountPaise}`,
      payment,
    };
  }
  if (payment.currency !== expectedCurrency) {
    return {
      ok: false,
      code: "currency_mismatch",
      message: `Razorpay currency ${payment.currency} != ${expectedCurrency}`,
      payment,
    };
  }
  // 'captured' is the strong success; 'authorized' means money's held by
  // Razorpay and will auto-capture. Both are acceptable — webhook will
  // upgrade authorized→captured later.
  if (payment.status !== "captured" && payment.status !== "authorized") {
    return {
      ok: false,
      code: "payment_not_captured",
      message: `Razorpay status=${payment.status} (need captured/authorized)`,
      payment,
    };
  }

  return { ok: true, payment };
}
