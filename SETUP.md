# EquipSeva Prod Setup Runbook

One-shot reference for the secret-and-config steps the founder (Ganesh) runs out-of-band — server-side code is already deployed for all of these. Each section's commands are independent; do them in any order as the corresponding external dependency activates.

---

## 1. GST invoice (round 463) — supplier identity secrets

**Status today:** Edge fn `generate_repair_invoice` deployed; refuses to render with `supplier identity unset` 500 until these are set. As soon as they're set, the "Download GST invoice" button on completed repair jobs renders a real PDF-ready HTML invoice.

```bash
# Required (refuses to render without all three):
supabase secrets set SUPPLIER_LEGAL_NAME="Dhanavath Ganesh Naik"
supabase secrets set SUPPLIER_TRADE_NAME="EquipSeva"
supabase secrets set SUPPLIER_GSTIN="<your-approved-GSTIN-from-2026-06-03>"
supabase secrets set SUPPLIER_ADDRESS="<biz address; multi-line OK>"
supabase secrets set SUPPLIER_STATE="Telangana"
supabase secrets set SUPPLIER_STATE_CODE="36"   # GST state code for Telangana
supabase secrets set SUPPLIER_PINCODE="<6-digit pin>"

# Optional (improves footer):
supabase secrets set SUPPLIER_EMAIL="ops@getphyllo.com"
supabase secrets set SUPPLIER_PHONE="+91-XXXXXXXXXX"
```

**Verify:**
```bash
supabase secrets list | grep SUPPLIER
```
Should show 7-9 SUPPLIER_* entries. Then open the app, tap a completed repair job, tap "Download GST invoice" — opens in browser, click "Print / Save as PDF".

---

## 2. Auto-email invoice on completion (round 463 epic)

**Status today:** Edge fns `dispatch_repair_invoice` + `founder_invoice_digest` deployed; trigger on `repair_jobs.status → completed` will fire `net.http_post` to dispatch fn IF `_app_repair_invoice_config` is seeded. Right now: not seeded → trigger fail-quiets → no auto-email.

```bash
# Step 1 — generate webhook secret
DISPATCH_SECRET=$(openssl rand -hex 32)
echo "$DISPATCH_SECRET"   # copy this — you'll paste it in the SQL seed below

# Step 2 — set secrets
supabase secrets set INVOICE_DISPATCH_SECRET="$DISPATCH_SECRET"
supabase secrets set FOUNDER_DIGEST_EMAIL="ops@getphyllo.com"

# Step 3 — confirm Resend is configured (already done historically, just verify)
supabase secrets list | grep -iE "RESEND"
# Expect RESEND_API_KEY + RESEND_FROM
```

**Step 4 — seed the webhook config via Supabase SQL editor** (https://supabase.com/dashboard/project/eyswaywvtartpvtoxtdr/sql/new):
```sql
INSERT INTO public._app_repair_invoice_config (id, webhook_url, webhook_secret)
VALUES (
  'singleton',
  'https://eyswaywvtartpvtoxtdr.functions.supabase.co/dispatch_repair_invoice',
  '<paste-DISPATCH_SECRET-from-step-1-here>'
)
ON CONFLICT (id) DO UPDATE
SET webhook_url=EXCLUDED.webhook_url,
    webhook_secret=EXCLUDED.webhook_secret,
    updated_at=now();
```

**Step 5 (Pro tier only) — schedule daily founder digest at 08:00 IST** (SQL editor):
```sql
SELECT cron.schedule(
  'founder_invoice_digest_daily',
  '30 2 * * *',  -- 02:30 UTC = 08:00 IST
  $$ SELECT net.http_post(
       url := 'https://eyswaywvtartpvtoxtdr.functions.supabase.co/founder_invoice_digest',
       headers := jsonb_build_object('x-webhook-secret', '<CRON_TICK_SECRET-value>'),
       timeout_milliseconds := 30000
     ); $$
);
```

**Verify auto-email lands:** Complete a real repair job in app → check the hospital's email inbox within ~30s.

---

## 3. Cashfree real payouts (when Activation activates)

**Status today:** "Activation in Process" per merchant.cashfree.com. KYC under review. Until approved, edge fn returns 503 + queue requeues (round 466 hardening). When approved:

```bash
# Step 1 — grab prod creds from merchant.cashfree.com → Payouts → Developers → API Keys → Production tab
# Step 2 — update secrets
supabase secrets set CASHFREE_CLIENT_ID="<prod-client-id-from-cashfree>"
supabase secrets set CASHFREE_CLIENT_SECRET="<prod-client-secret-from-cashfree>"

# Step 3 — drain the accumulated queue (manually trigger cron, skips 5-min wait)
gh workflow run engineer-payouts-worker.yml
sleep 60
gh run list --workflow=engineer-payouts-worker.yml --limit 1
```

**Verify dispatch:**
```bash
# Check recently dispatched payouts (should see status='processing' with razorpay_payout_id set)
supabase db query --linked "SELECT id, status, amount_paise, razorpay_payout_id, processed_at FROM public.engineer_payouts WHERE status IN ('processing','processed') ORDER BY updated_at DESC LIMIT 10;"

# Check dead-letter count (rounds 466 + 468)
supabase db query --linked "SELECT * FROM public.founder_payouts_dead_letter_summary();"

# Check engineers stuck on no-method (round 468)
supabase db query --linked "SELECT * FROM public.founder_engineer_payouts_no_method_summary();"
```

**Cashfree wallet funding:** Cashfree dispatches FROM your prefunded balance, NOT from your Razorpay merchant account. Fund via NEFT/RTGS — the merchant dashboard shows a virtual account number for top-ups.

---

## 4. Ship v0.3.1 AAB to Play Store

**Status today:** Signed AAB sitting at https://github.com/ganeshnaik166/equipseva-android/releases/tag/v0.3.1. Round 467 + 468 are SERVER-ONLY — no AAB re-cut needed.

1. Download `app-release.aab` from the release page
2. Play Console → EquipSeva → Testing → Internal testing → Create new release
3. Upload the AAB
4. Release notes (paste verbatim):
   ```
   v0.3.1 — accessibility, realtime, payout pipeline polish

   • A11y: 48dp touch targets, status banner liveRegion, heading semantics
   • Chat: typing indicator no longer leaks between conversations; sign-out cleans observer
   • Edge fns: 4-min budget + abort handling on payouts worker
   • Server-side audit-5 + 6 hardening (already live): AMC engineer payouts, tamper lockdown, Cashfree reconciliation, grant-layer defense, dispatch hardening
   ```
5. Start rollout to Internal testing
6. Install via Play Store on your device (1-3 min to surface)

---

## 5. Smoke test the full path (when 1-4 done)

1. Sign in as a real hospital → book a repair → engineer accepts → completes
2. Hospital pays via Razorpay → escrow forms
3. Hospital taps "Release early" → engineer_payouts auto-queues
4. Within 5 min, Cashfree dispatches ₹85% of contract → engineer's UPI/bank
5. Hospital receives GST invoice email within ~30s of completion
6. Next morning at 08:00 IST, founder receives daily digest of all invoices

All five steps require zero code changes — just the secrets + Cashfree activation + AAB upload above.

---

## Diagnostic queries (paste into Supabase SQL editor anytime)

```sql
-- Recent payout pipeline state
SELECT status, count(*), sum(amount_paise) / 100.0 AS total_rupees
FROM public.engineer_payouts
WHERE queued_at > now() - interval '7 days'
GROUP BY status ORDER BY 1;

-- Stuck queue rows
SELECT * FROM public.founder_engineer_payouts_no_method_summary();
SELECT * FROM public.founder_payouts_dead_letter_summary();

-- Recent invoices emailed
SELECT invoice_number, hospital_email, gross_rupees, email_status, sent_at
FROM public.repair_invoice_emails
WHERE sent_at > now() - interval '7 days'
ORDER BY sent_at DESC;

-- Verify column-level lockdown (round 467)
SELECT
  has_column_privilege('authenticated','public.repair_jobs','engineer_payout','UPDATE') AS payout_locked_should_be_false,
  has_column_privilege('authenticated','public.repair_jobs','platform_commission','UPDATE') AS commission_locked_should_be_false,
  has_column_privilege('authenticated','public.repair_jobs','is_warranty_covered','UPDATE') AS warranty_locked_should_be_false,
  has_column_privilege('authenticated','public.repair_jobs','engineer_id','UPDATE') AS engineer_id_locked_should_be_false;
```

---

## Project handles

- **Supabase project ref:** `eyswaywvtartpvtoxtdr`
- **Edge fn URL base:** `https://eyswaywvtartpvtoxtdr.functions.supabase.co/<fn-name>`
- **Founder email (for is_founder() gate):** `ganesh1431.dhanavath@gmail.com`
- **GitHub repo:** `ganeshnaik166/equipseva-android`
- **Latest deploy state tag:** `v0.3.1-server-r468`

When in doubt, `git log --oneline -20` shows recent changes.
