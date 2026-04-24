# verify-razorpay-payment

Server-side Razorpay signature verification. Called by the Android client after
`RazorpayLauncher` receives a success callback. Flips `spare_part_orders.payment_status`
to `completed` only after HMAC-SHA256 check against the Razorpay key secret.

## Deploy

```bash
supabase functions deploy verify-razorpay-payment
supabase secrets set RAZORPAY_KEY_SECRET=<from razorpay dashboard>
# RAZORPAY_KEY_ID mirrors BuildConfig.RAZORPAY_KEY on the client; keeping a server-side
# copy is optional but useful for future amount re-checks against Razorpay's order API.
supabase secrets set RAZORPAY_KEY_ID=<rzp_test_... or rzp_live_...>
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected.
Identity check uses the anon key + caller bearer header; the privileged write uses
service-role on a separate client.

## Contract

**Request (JSON, POST, Bearer JWT):**

```json
{
  "order_id": "uuid",
  "razorpay_order_id": "order_xxx",
  "razorpay_payment_id": "pay_xxx",
  "razorpay_signature": "<hex64>"
}
```

**Success 200:**

```json
{
  "ok": true,
  "order_id": "uuid",
  "payment_id": "pay_xxx",
  "payment_status": "completed",
  "order_status": "confirmed"
}
```

**Errors:** 400 `invalid_signature` / `bad_request` / `amount_mismatch`,
401 `unauthenticated`, 403 `unauthenticated` (not owner), 404 `order_not_found`,
405 bad method, 500 `server_error`.

## Testing

Local (requires `supabase start`):

```bash
supabase functions serve verify-razorpay-payment --env-file ./supabase/.env.local
```

Signature-mismatch smoke test:

```bash
curl -X POST http://localhost:54321/functions/v1/verify-razorpay-payment \
  -H "authorization: Bearer <user-jwt>" \
  -H "content-type: application/json" \
  -d '{"order_id":"<uuid>","razorpay_order_id":"order_test","razorpay_payment_id":"pay_test","razorpay_signature":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'
# expect 400 invalid_signature
```
