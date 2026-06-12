# EquipSeva v0.4 — Engineering Bible (Master Index)

Caveman speak. Engineer-precise. 27 features. 4 phases. ~9 month runway.

---

## 1. Table of Contents — Features by Phase

### Phase 1 — Legal Floor (18 days, parallelizable)

| # | Feature | Days | Critical Deps |
|---|---------|------|---------------|
| 1.1 | Founder Action Audit Log | 3 | None. Pair with Round 481 founder RPC scope |
| 1.2 | DPDP Grievance Officer + 72hr Breach Tracker | 5 | Storage bucket `dpdp-grievance-docs`, pg_cron, email service |
| 1.3 | Consent Versioning + Purpose Ledger | 4 | Storage for PDFs, DataStore pattern (like `PendingEscrowPaymentsStore`), legal docs |
| 1.4 | Chat Rate-Limit RPC | 2 | Existing `post_chat_message` RPC |
| 1.5 | Chat Auto-Archive on Repair Complete | 1 | `complete_repair_job` RPC (Round 420) |
| 1.6 | Hard-Gate Device Taxonomy (Class A/B + AERB + MTP/PCPNDT) | 3 | CDSCO rules ref, state ban-list, migration on `catalog_devices` |

**Phase 1 verdict:** ship parallel. 1.4 + 1.5 trivial — bundle together as one PR. 1.6 needs founder legal review before code. Phase 1 unblocks Play Store sleep-easy.

### Phase 2 — Money Spine (24.5 days)

| # | Feature | Days | Critical Deps |
|---|---------|------|---------------|
| 2.1 | Refund Authorization Workflow | 3.5 | `repair_job_escrow` (PR-D4), `engineer_payouts` (R422), `is_founder()` |
| 2.2 | Three-Way Reconciliation + Daily Cron + Drift Alert | 5 | `razorpay_webhook_events` (R471), `get_repair_invoice_payload` (R449), pg_cron |
| 2.3 | Smart Escrow 48h Auto-Release + Dispute Pause | 2.5 | Escrow tables (R520), `complete_repair_job` payout cols (R620), hourly cron |
| 2.4 | UPI Intent as Default Payment | 3 | `amc_payment_orders` (R510), Razorpay SDK v3.10+, `verify-amc-payment` (R473) |
| 2.5 | GST Auto-Invoice + Dual-GSTIN + Reverse-Charge | 4.5 | `profiles.gstin` (R449), `get_repair_invoice_payload`, Storage, email |
| 2.6 | Section 194-O TDS + Form 26AS Reconciliation | 6 | `engineer_payouts` FSM (R422), Cashfree payout API, dispatch cron (R424) |

**Phase 2 verdict:** sequence critical. 2.1 → 2.2 → 2.3 must be serial (escrow + reconciliation share state). 2.4 (UPI) + 2.5 (GST) parallel after 2.2 lands. 2.6 (TDS) last — touches every payout.

### Phase 3 — Evidence (172 days raw — biggest phase, heaviest decomposition needed)

| # | Feature | Days | Critical Deps |
|---|---------|------|---------------|
| 3.1 | Pre-Visit Engineer Dossier (PVED) | 21 | KYC schema, face-match API (Rekognition/TF Lite), Aadhaar OCR |
| 3.2 | Digital Service Report + Aadhaar eSign | 28 | Calibration UI, parts table, NSDL/Digilocker API, PDF template lib |
| 3.3 | Dispute Defense Vault (Engineer) | 21 | `repair_job_photos`, chat messages, location, signatures, trigger logic |
| 3.4 | Dispute Mediation Console (Founder) | 14 | 3.3 vault complete, escrow dispute cols, hospital claim storage |
| 3.5 | §65B Chain-of-Custody (SHA-256 + CAS) | 21 | 3.3 vault complete, Storage hashing, §65B PDF template |
| 3.6 | NABH-Ready Per-Job PDF Export (COP-6) | 21 | 3.2 DSR template, IEC 62353 readings, parts batch/serial, lab certs |
| 3.7 | AMC-Checker Upload + Signed Affidavit | 18 | Hospital service form, PDF OCR (Textract/Tesseract), affidavit template |
| 3.8 | Engineer Periodic Re-KYC (12mo cycle) | 35 | DigiLocker OAuth, Authbridge API, push, soft-block gating in `accept_repair_bid` |

**Phase 3 verdict:** must decompose. See §6.

### Phase 4 — Console + Fleet (76 days)

| # | Feature | Days | Critical Deps |
|---|---------|------|---------------|
| 4.1 | Biomedical Coordinator Web Console | 12 | `auth.users` + `profiles`, RLS role expansion |
| 4.2 | Equipment Fleet Console + MTBF/MTTR Dashboard | 10 | `repair_jobs` time tracking, `is_founder()`, equipment FK |
| 4.3 | Code Red Emergency Override (60-min SLA) | 14 | WhatsApp Business API, Twilio SMS, Slack webhook, FCM tokens |
| 4.4 | Predictive PM Calendar + Auto-Quote | 9 | `repair_jobs.kind='maintenance'`, cost history, iCal gen |
| 4.5 | NABH Evidence Vault Auto-Bundle Export | 11 | `repair_job_photos`, Storage `/nabh-bundles/`, PDF lib |
| 4.6 | Engineer SLA + Weekend Coverage Board | 8 | Job timestamps, engineer location, founder role |
| 4.7 | Master PI Policy ₹10Cr + DPO + DPA Template | 12 | Storage PDFs, Slack, founder auth |

---

## 2. Critical-Path Gantt — Week-by-Week

Assume 2 engineers (founder + 1 contractor). ~9 month plan. Calendar weeks numbered from v0.4 kickoff.

```
Wk  | Track A (Founder)              | Track B (Contractor)        | Notes
----|--------------------------------|-----------------------------|------
W1  | 1.4 Chat Rate-Limit            | 1.1 Founder Audit Log       | Phase 1 sprint
W1  | 1.5 Auto-Archive (1d combo)    | -                           |
W2  | 1.6 Device Taxonomy            | 1.2 DPDP Grievance          | Legal-floor stretch
W3  | 1.3 Consent Versioning         | 1.2 DPDP cont.              |
W4  | 2.1 Refund Auth                | 2.2 Three-Way Recon         | Phase 2 begins
W5  | 2.3 Smart Escrow 48h           | 2.2 cont.                   |
W6  | 2.5 GST Invoice                | 2.4 UPI Intent              | Parallel tracks
W7  | 2.5 cont.                      | 2.6 TDS Section 194-O       |
W8  | 2.6 TDS cont.                  | 2.6 TDS cont.               | Both on TDS — touchy
W9  | 3.1 PVED (broken: face-match)  | 3.3 Vault foundation        | Phase 3 begins
W10 | 3.1 PVED (OCR + dossier UI)    | 3.3 Vault triggers          |
W11 | 3.1 PVED ship                  | 3.5 §65B hashing            |
W12 | 3.2 DSR template + readings    | 3.5 §65B cert PDF           |
W13 | 3.2 DSR Aadhaar eSign          | 3.3 Vault ship              |
W14 | 3.2 DSR ship                   | 3.4 Mediation Console       |
W15 | 3.7 AMC-Checker OCR            | 3.4 cont.                   |
W16 | 3.7 affidavit + ship           | 3.6 NABH COP-6 export       |
W17 | 3.8 Re-KYC DigiLocker          | 3.6 cont.                   |
W18 | 3.8 Re-KYC Authbridge          | 3.6 ship                    |
W19 | 3.8 Re-KYC soft-block + push   | 4.1 Coordinator Console     | Phase 4 begins
W20 | 3.8 ship                       | 4.1 cont.                   |
W21 | 4.3 Code Red infra (WA + SMS)  | 4.2 Fleet Console + MTBF    |
W22 | 4.3 Code Red parallel page     | 4.2 cont.                   |
W23 | 4.3 ship                       | 4.4 Predictive PM           |
W24 | 4.5 NABH Bundle Export         | 4.6 Engineer SLA Board      |
W25 | 4.7 PI Policy + DPA            | 4.6 ship                    |
W26 | 4.7 ship + v0.4 RC             | Buffer / hotfixes           |
```

**Critical path:** 1.6 → 2.2 → 2.3 → 3.3 → 3.5 → 4.5 (the evidence + reconciliation spine). Slip here = whole release slips.

**Parallelizable:** 1.4, 1.5, 2.4, 2.5, 4.4, 4.6, 4.7. Lateral risk low.

**Hard sequencing locks:**
- 3.4 needs 3.3 done (mediation reads vault)
- 3.5 needs 3.3 done (hashing reads vault files)
- 3.6 needs 3.2 done (shares PDF template)
- 4.5 needs 3.6 done (bundle export reuses COP-6)

---

## 3. Cross-Feature Data Model Summary

### New tables (24)

| Table | Owner Feature | Purpose |
|-------|---------------|---------|
| `founder_action_audit_log` | 1.1 | Every founder RPC call recorded |
| `dpdp_grievance_tickets` | 1.2 | Ticket + SLA deadline |
| `dpdp_breach_events` | 1.2 | 72h breach tracker rows |
| `consent_versions` | 1.3 | Immutable T&C/Privacy text |
| `user_consent_ledger` | 1.3 | Who consented to what version when |
| `rate_limit_events` | 1.4 | Sliding-window chat events |
| `device_state_restrictions` | 1.6 | State-level MTP/PCPNDT bans |
| `validation_audit` | 1.6 | Class A/B + AERB validation trace |
| `refund_requests` | 2.1 | Refund req + founder approval |
| `reconciliation_runs` | 2.2 | Daily 3-way recon snapshot |
| `reconciliation_drift_alerts` | 2.2 | Mismatches escalated |
| `escrow_auto_release_jobs` | 2.3 | Cron candidates |
| `gst_invoices` | 2.5 | One per repair job |
| `tds_ledger` | 2.6 | Per-engineer FY cumulative payout |
| `tds_certificates` | 2.6 | Quarterly Form 16A artefacts |
| `engineer_dossiers` | 3.1 | PVED snapshot per job |
| `face_match_attempts` | 3.1 | Score + decision log |
| `digital_service_reports` | 3.2 | DSR + eSign txn id |
| `repair_job_parts_used` | 3.2 | Batch/serial/license per part |
| `dispute_evidence_vaults` | 3.3 | Manifest + manifest hash |
| `chain_of_custody_certs` | 3.5 | §65B cert + SHA-256 chain |
| `amc_uploads` | 3.7 | OCR raw + parsed |
| `engineer_rekyc_cycles` | 3.8 | 12mo cycle FSM |
| `code_red_pages` | 4.3 | 3-engineer parallel page audit |

### New columns on existing tables

| Table | Columns |
|-------|---------|
| `catalog_devices` | `risk_class enum`, `is_aerb bool`, `mtp_flag bool`, `pcpndt_flag bool` |
| `repair_jobs` | `escrow_auto_release_at`, `dispute_paused_at`, `nabh_export_version`, `code_red bool`, `pm_predicted_at` |
| `chat_conversations` | `archived_at`, `archived_reason` |
| `engineers` | `rekyc_due_at`, `rekyc_status enum`, `last_authbridge_ref`, `last_digilocker_ref` |
| `engineer_payouts` | `tds_amount_paise`, `tds_fy`, `refund_request_id fk` |
| `profiles` | `gstin`, `business_address jsonb` (if not already) |
| `repair_job_escrow` | `disputed_at`, `auto_release_locked bool` |

### New indices (need explicit declaration)

- `idx_founder_audit_actor_time (actor_id, created_at desc)`
- `idx_rate_limit_user_window (user_id, created_at)`
- `idx_recon_run_date (run_date desc)` unique
- `idx_escrow_release_due (escrow_auto_release_at) where dispute_paused_at is null`
- `idx_dossier_job (repair_job_id)` unique
- `idx_vault_manifest_hash (manifest_sha256)` unique
- `idx_tds_engineer_fy (engineer_id, fy)`
- `idx_rekyc_due (rekyc_due_at) where rekyc_status != 'completed'`

---

## 4. Cross-Feature API Surface

### New RPCs (Postgres functions)

```
log_founder_action(action_kind text, payload jsonb)
file_dpdp_grievance(payload jsonb) → ticket_id
mark_dpdp_breach_resolved(ticket_id uuid, resolution_note text)
record_user_consent(consent_version_id uuid, purpose text[])
get_latest_consent_versions() → table
check_chat_rate_limit(user_id, window_seconds) → {ok, reset_at, remaining}
validate_device_listing(device_id, state_id) → {ok, reasons[]}
request_refund(repair_job_id, reason_text, amount_paise) → refund_id
approve_refund(refund_id, founder_note) -- founder-only
reject_refund(refund_id, founder_note) -- founder-only
run_daily_reconciliation(target_date date) → recon_run_id
get_reconciliation_drift(run_id) → table
auto_release_escrow(escrow_id) -- cron-only
pause_escrow_for_dispute(escrow_id, opened_by)
issue_gst_invoice(repair_job_id) → invoice_id
calculate_tds(engineer_id, gross_paise, fy) → tds_paise
record_tds_deduction(payout_id, tds_paise)
generate_form_26as_export(fy text, quarter int) → storage_path
generate_engineer_dossier(repair_job_id) → dossier_id
record_face_match_attempt(dossier_id, score numeric, decision text)
sign_dsr(dsr_id, aadhaar_otp_ref) -- via eSign edge fn
finalize_dispute_vault(repair_job_id) → vault_id, manifest_sha256
issue_chain_of_custody_cert(vault_id) → cert_url
upload_amc_document(repair_job_id, storage_path, ocr_payload jsonb)
start_engineer_rekyc(engineer_id) → cycle_id
complete_engineer_rekyc(cycle_id, digilocker_ref, authbridge_ref)
soft_block_engineer_if_rekyc_overdue(engineer_id) -- called inside accept_repair_bid
predict_pm_due_date(equipment_id) → date
trigger_code_red(repair_job_id, severity text) → page_id
get_mtbf_mttr(equipment_id, window_days int) → {mtbf, mttr}
```

### New edge functions

```
generate-invoice-pdf            -- GST + reverse-charge layout
generate-dsr-pdf                -- ICMED/COP-6 template
generate-nabh-bundle-zip        -- COP-6 + photos + certs
generate-§65b-cert-pdf          -- chain-of-custody PDF
ocr-amc-document                -- Textract/Tesseract wrapper
face-match-engineer             -- Rekognition or TF Lite
esign-aadhaar-otp               -- NSDL/Digilocker proxy
digilocker-degree-fetch         -- 3.8 re-KYC
authbridge-police-check         -- 3.8 re-KYC
send-tds-certificate-email      -- 2.6 quarterly mail-out
code-red-fanout                 -- WhatsApp + SMS + Slack + FCM
reconciliation-cron-tick        -- GH Actions or pg_cron entrypoint
escrow-auto-release-tick        -- hourly cron
rekyc-reminder-tick             -- daily cron
```

### New cron schedules (pg_cron)

- `reconciliation-daily` @ 02:00 IST
- `escrow-auto-release` hourly
- `rekyc-due-reminder` daily 09:00 IST
- `dpdp-breach-deadline-watch` hourly
- `tds-quarterly-cert-mail` 1st of Apr/Jul/Oct/Jan

---

## 5. Top 5 Highest-Risk Specs

### Risk 1 — Section 194-O TDS (2.6): FY boundary + PAN validation
**Why scary:** wrong TDS = IT notice + penalty + engineer refuses to work. FY boundary edge case (31-Mar payout) trivial to mis-code.
**Mitigation:** unit-test `calculate_tds` with 12 FY-boundary fixtures (28-Feb, 31-Mar 11:59 IST, 1-Apr 00:01). Server accepts any PAN format; client validates 10-char + char-9-alpha checksum. Add `tds_dry_run_mode` for first 2 weeks — log what would have been deducted, don't actually deduct. Founder reviews ledger daily, flips to live mode after 14 clean days.

### Risk 2 — DSR + Aadhaar eSign (3.2): NSDL downtime
**Why scary:** NSDL/Digilocker SLA not ours. If down 4 hours = ~20 jobs stuck unsigned = engineers can't claim payout = churn risk.
**Mitigation:** queue eSign jobs in `esign_pending` state visible to both parties. Retry every 5 min for 24h. Allow founder to manually mark "signed offline" with notarized doc upload as last-resort fallback. SLA dashboard for NSDL uptime — alert founder Slack on 3 consecutive failures.

### Risk 3 — Three-Way Reconciliation (2.2): floating-point + timezone
**Why scary:** ₹1 daily drift = ₹365/year reported. ₹100 daily drift = founder gets paranoid. Worse: silent drift goes undetected → audit blowup.
**Mitigation:** ALL money columns `numeric(12,2)` — never float, never integer paise (well, paise OK if `bigint`). All recon timestamps converted to IST via `timezone('Asia/Kolkata', now())`. Recon emits alert on drift >₹1 — founder triages within 24h. Add manual reconciliation override RPC for known explainable gaps (refunds in flight, etc.).

### Risk 4 — Engineer Re-KYC (3.8): DigiLocker DSC infra outage
**Why scary:** 35-day spec already biggest. If DigiLocker down for a week, every overdue engineer soft-blocked → no jobs accepted → revenue stalls.
**Mitigation:** 30-day grace period before soft-block. Manual degree re-upload as fallback (founder approves). Engineer can self-trigger early re-KYC at month 11 to dodge crunch. Authbridge "flagged" ≠ "rejected" — 14-day founder review window before any action.

### Risk 5 — Face-Match in PVED (3.1): false positives → hospital distrust
**Why scary:** bad lighting kills the score. If hospital sees "match: 58%" they panic. If we hide the score, we lose transparency. Either way feature value erodes.
**Mitigation:** show score ONLY with band labels ("High confidence" >85, "Verify in-person" 60-85, "Manual review" <60). Sub-60 auto-routes to founder review queue — never blocks job. Pre-flight tip on engineer app: "stand near window light, no hat." Track score distribution monthly to detect API drift.

---

## 6. Specs Needing Decomposition (>10 days)

Three biggies. Each must split into shippable sub-stories or risk solo-engineer burnout + integration debt.

### 6.1 — Engineer Re-KYC (3.8, 35 days) → 4 stories

1. **3.8a — Schema + Cycle FSM (5d):** `engineer_rekyc_cycles` table, status enum, due-date computation, founder-visible dashboard. Ship dark.
2. **3.8b — DigiLocker Degree Fetch (10d):** OAuth, fetch endpoint, store ref, fallback manual upload. Behind feature flag.
3. **3.8c — Authbridge Police Check (10d):** integration, consent flow, "flagged" handling, founder review queue. Behind flag.
4. **3.8d — Soft-Block + Push + Launch (10d):** gate inside `accept_repair_bid`, push reminders at T-30/T-7/T-0, 30-day grace, launch flag flip.

Each sub-story independently testable + reversible.

### 6.2 — Digital Service Report + eSign (3.2, 28 days) → 3 stories

1. **3.2a — Calibration Readings + Parts UI (8d):** capture pre/post readings, `repair_job_parts_used` table + form. Pure CRUD, ship behind flag.
2. **3.2b — DSR PDF Template + ICMED/COP-6 Layout (10d):** HTML→PDF via Puppeteer edge fn. Founder reviews 10 sample PDFs before unlock.
3. **3.2c — Aadhaar eSign Integration + Queue (10d):** NSDL OTP, signing edge fn, 5-min retry loop, "signed offline" fallback. Hardest part — own sprint.

### 6.3 — Code Red Emergency Override (4.3, 14 days) → 2 stories

Borderline (14d) but multi-vendor risk (WhatsApp + Twilio + Slack + FCM = 4 failure modes). Split:

1. **4.3a — Trigger + Persistence + FCM Page (6d):** `trigger_code_red` RPC, `code_red_pages` table, FCM fanout to top-3 nearest engineers. Ship dark — founder-only trigger first.
2. **4.3b — WhatsApp + SMS + Slack Fanout (8d):** WhatsApp Business group create, Twilio SMS, Slack webhook, retry logic, SLA timer. Launch with founder dry-run for 1 week.

**Also-watch (close to 10d cap, monitor for scope creep):**
- 3.1 PVED (21d) — split into face-match + OCR + dossier UI as 3×7d if it slips
- 3.3 Vault (21d) — split into trigger + storage + manifest if it slips
- 3.5 §65B (21d) — depends entirely on 3.3, sequence-locked
- 3.6 NABH COP-6 (21d) — split into template + IEC readings + cert embedding
- 3.7 AMC-Checker (18d) — split into OCR + affidavit if slips
- 4.1 Console (12d), 4.3 Code Red (14d done above), 4.7 PI Policy (12d) — keep whole, monitor

---

End of engineering bible. Cross-reference with `docs/ROADMAP_v04.md` for product framing. This doc owns: deps, sequencing, schema/API surface, risk + decomposition decisions.
