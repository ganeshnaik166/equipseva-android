# Founder Operator Runbook

> **Audience:** Founder (Ganesh) when something needs attention or breaks at 2am.
>
> **Last updated:** 2026-06-14 · v0.4-day-3-ultra7

This document is a flat list of "if X happens, do Y" entries. Skim by symptom.

---

## 0. Daily morning routine (5 minutes)

Login → check these three pages **in this order**:

1. **`/dashboard`** — read the Triage now row. Pills shown only when count > 0.
2. **`/health`** — check "N/M signals green" pill. If anything red, click through.
3. **`/onboarding`** — if engineers are stuck > 24h, approve / reject so SLA stays in range.

If all green and no triage pills → close the tab. Five minutes done.

---

## 1. Symptom-keyed incident playbook

### A. Razorpay payment stuck / order pending

**Where you see it:**
- Hospital pings on WhatsApp: "I paid, app still says pending"
- Or `/webhooks` filter=`failed` shows a row

**Diagnose:**
1. `/webhooks?filter=failed` — find the event_type and razorpay_order_id
2. Cross-check with `/audit?op=verify` (filter for payment verification ops)
3. Click through the engineer or hospital drilldown if it points at one

**Fix:**
- If webhook **never received**: usually network — Razorpay retries for 24h. Wait.
- If webhook **received but apply_error**: payment_admin_events ledger will have the error string. Most common cause is amount mismatch (Razorpay sent ₹X but our order said ₹Y). Open the row in Supabase SQL editor to inspect.
- If genuinely stuck: file a Razorpay support ticket with the event_id from `/webhooks`.

### B. Payout to engineer failed

**Where you see it:**
- `/payouts?status=failed` shows rows
- Or `/health` "Payout dead-letter" stat > 0

**Diagnose:**
1. Click the row → `/payouts/[id]` for the lifecycle
2. The Cashfree webhook section (matched by UTR) shows the failure reason
3. Common failure reasons:
   - `BENEFICIARY_BANK_DOWN` — retry tomorrow
   - `INVALID_ACCOUNT` — engineer needs to fix bank details in KYC
   - `INSUFFICIENT_BALANCE` — top-up Cashfree wallet (founder action)
   - `KYC_PENDING` — engineer needs to complete Cashfree-side KYC

**Fix:**
- For `INVALID_ACCOUNT` / `KYC_PENDING`: tap **Cancel** on the payout (logs to founder_action_log), nudge engineer via WhatsApp, then re-queue manually via the Supabase SQL editor (`process-engineer-payouts` edge fn re-fires).
- For `INSUFFICIENT_BALANCE`: top up at merchant.cashfree.com.

### C. Reconciliation anomaly fires

**Where you see it:**
- `/health` "Recon anomalies (3d)" stat > 0 in warn/danger tone
- Or `/reconciliation` shows status="anomaly" row in last 14d

**Diagnose:**
1. `/reconciliation` — anomalies table at bottom shows source + delta + details JSONB
2. Most common: small rounding mismatch (₹1-2). Ignore unless > ₹100.
3. Real signal: large delta_rupees on `gst_mismatch` or `escrow_mismatch` kind.

**Fix:**
- If small rounding: open the row's details JSON, confirm rounding source, close out via SQL.
- If large: STOP. File for forensic review. The anomaly is the audit trail — do NOT delete the row.

### D. DPDP grievance approaching 30-day deadline

**Where you see it:**
- `/dashboard` Triage now row shows "DPDP grievances open" in red
- Or `/dpdp` rows show deadline_at < now() (red Deadline column)

**Fix:**
- Open the row, click **In progress** → write down what you're doing
- Resolve within 30 days from filing OR escalate to DPO panel
- Click **Resolved** with the disposition note when done
- All three states (in_progress / resolved / rejected) log to founder_action_log

### E. Dispute escrow stuck

**Where you see it:**
- `/disputes` shows old open disputes
- Engineer or hospital pings about a payment that hasn't moved

**Diagnose:**
1. Open `/disputes` → the row's escrow id
2. If escrow was funded > 48h ago without engineer arrival, it's auto-release territory
3. If engineer arrived but hospital is stalling signoff, that's mediation territory

**Fix:**
- **Force release** button on `/disputes` row → enter ≥10-char reason → logs to founder_action_log and releases escrow to engineer
- Use this for: dispute resolved off-platform, hospital ghosted after signoff window, etc.
- Do NOT use for: actively disputed escrow where the hospital has a legitimate complaint (those need the evidence-pack mediation flow)

### F. Engineer KYC sitting > 24h

**Where you see it:**
- `/onboarding` rows older than 24h show in warn (yellow)
- > 7d shows in red on the "Overdue" KPI

**Fix:**
- Click the engineer name to land on `/engineers/[id]` drilldown
- Review the certificates JSONB attached to the row
- **Approve** if docs are legit (optional note logged)
- **Reject** with reason + comma-sep rejected_doc_types (e.g. "aadhaar,certificates")
- Engineer gets push notification via existing kyc_status_changed trigger
- All states log to founder_action_log

### G. Code Red emergency timeout

**Where you see it:**
- `/ops` "Code Red (last 30 days)" rows with status="no_response"
- Hospital ICU calls in person

**Fix:**
- These are 60-minute SLA. If SLA expired, engineer pool failed to pick up.
- Manually call the on-call engineer (founder phonebook).
- Backfill the row in Supabase SQL editor with `manual_accepted` state.

### H. Bonded part installed but no QR scan recorded

**Where you see it:**
- `/supply` "Unmatched QR scans" stat > 0

**Diagnose:**
- Means an engineer logged a part_installed event without scanning a known tamper QR
- Could be: (a) honest mistake — engineer used a part from a different lot, (b) counterfeit
- BNS §304A liability — this is the criminal-grade compliance signal

**Fix:**
- Track the engineer, the job, the part claimed
- If genuine: re-log the dispatch row with the correct intake_id
- If suspicious: pause the engineer, freeze the parts ledger, escalate to founder counsel

---

## 2. Recurring scheduled checks

### Once per week (Mondays)
- `/finance` — confirm TDS pending = 0 (deposit any open quarters via SQL editor + the e-payment portal)
- `/audit?days=7` — skim the week's founder actions; anything that doesn't look right?
- `/risk` — clear false-positive flags so the queue stays focused
- `/cohorts` — check hospital retention curve is intact

### Once per month
- `/funnel` — check conversion is trending right; if step-N retention drops > 10pp month-over-month, that's a product signal
- `/engineers` — top-10 should be earning at expected levels; if not, retention risk

### Once per quarter (FY boundaries Apr 1 / Jul 1 / Oct 1 / Jan 1)
- `/finance` — file GSTR-1 + GSTR-3B against the quarter's invoices
- `/finance` — deposit accumulated §194-O TDS to Govt and capture challan in the row's `deposited_at`
- Quarterly board pack — print `/investor` to PDF and circulate

---

## 3. Founder-only emergency commands (Supabase SQL editor)

When the Web Console can't do what you need:

```sql
-- Manually mark a payout paid + UTR
SELECT public.admin_mark_engineer_payout_paid(
  '<payout_id>'::uuid,
  '<utr>',
  'IMPS',
  'manual via SQL — Web Console blocked'
);

-- Manually approve a refund authorization
SELECT public.approve_refund_authorization(
  '<request_id>'::uuid,
  'manual via SQL'
);

-- Force-pause an engineer (verification → 'pending', kicks them out of the directory)
SELECT public.admin_set_engineer_verification(
  '<user_id>'::uuid,
  'pending',
  'manual pause pending review',
  ARRAY['conduct']
);

-- Look up an engineer's full row
SELECT * FROM public.engineers WHERE user_id = '<user_id>'::uuid;

-- Re-run reconciliation for a specific date
SELECT public.run_reconciliation_for_date(CURRENT_DATE - 1);
```

---

## 4. Escalation contacts (kept in 1Password)

- **Supabase support:** dashboard → Help (use account-tied email)
- **Razorpay support:** support@razorpay.com — include event_id from `/webhooks`
- **Cashfree support:** support@cashfree.com — include payout_id from `/payouts/[id]`
- **CDSCO advisory:** counsel name from `docs/CDSCO_REPRESENTATION_LETTER_DRAFT.md`
- **DPDP DPO panel:** counsel name from `docs/v04/DPDP_POSTURE.md` (not yet drafted — TODO)
- **Insurance broker (PI):** TBD — RFP not yet bound

---

## 5. Read order for a new operator (someone else, when you hire)

If you ever hand off founder ops to another human, ask them to read in this order:

1. `docs/ROADMAP_v04.md` — what we built and why
2. `docs/ROADMAP_v05.md` — what we're building next
3. `docs/VERTICAL_PICK_DENTAL.md` — vertical strategy
4. This runbook
5. The Web Console itself — click through every nav item, read each empty state

That gets them to "useful in 4 hours."

---

## 6. What this runbook does NOT cover

- **Onboarding a new bonded supplier** — see `/supply` form footer; intake form is wired
- **Onboarding a hospital chain** — v0.5 Phase 1 work, not yet shipped
- **Founder phone unreachable** — no fallback plan yet (TODO: backup founder)
- **Supabase outage** — depend on SLA; cron is best-effort

---

_Pattern: every entry should be one paragraph + one fix. If it's longer, it's not a runbook entry — it's a feature_.
