# EquipSeva v0.4 Roadmap

> **Source:** Synthesis of 5-perspective brainstorm (hospital-admin / biomedical-engineer / founder-ops / senior-PM / risk-counsel) + skeptic-panel kill-shot mitigations + audit-9/10 deferred items.
>
> **Drafted:** 2026-06-12 · Founder: Ganesh Dhanavath · Author: Claude (acting PM/CEO/QA per [project-ownership memory](https://github.com/ganeshnaik166/equipseva-android))
>
> **Status:** Awaiting founder sign-off before kicking off Phase 1.

---

## 1. v0.4 Mission

Make EquipSeva trustworthy enough that big hospital sign without WhatsApp side-deal, while engineer feel safe leave WhatsApp cash.

**One sentence:** _Lock down trust, money, evidence — so growth no kill us._

---

## 2. The 5 Phases

### Phase 1 — Legal Floor (3 weeks · target +1 week buffer)
**Goal:** No go jail. No lose safe harbour. Foundation before fancy stuff.

| Feature | Effort | Lens / Source |
|---|---|---|
| Founder Action Audit Log (`founder_action_log` central table + RLS) | 1w | founder-ops (audit-10 gap) |
| DPDP Grievance Officer screen + 72hr breach-response tracker | 2w | risk-counsel |
| Consent Versioning + Purpose Ledger | 3w (parallel) | risk-counsel |
| Chat rate-limit RPC (sliding-window) | 1w | audit-9 deferred |
| Chat auto-archive on repair_job complete | 2w | audit-9 deferred |
| Hard-gate device taxonomy (AERB / MTP / PCPNDT server-side block) | 2w | skeptic-panel #6 |

**Why first:** Cheap. Mandatory. Block lawsuit before chase revenue.

---

### Phase 2 — Money Spine (4 weeks)
**Goal:** Every rupee traced. No fat-finger refund. No silent drift.

| Feature | Effort | Lens / Source |
|---|---|---|
| Refund Authorization Workflow (founder-approve + reason audit) | 2w | founder-ops |
| Three-Way Recon (Razorpay + Cashfree + GST) | 3w | founder-ops |
| Smart Escrow with Auto-Release | 3w | engineer |
| UPI Intent flow as default (replace collect flow) | 1w | senior-PM |
| GST Auto-invoice (engineer side) + dual-GSTIN + RCM flag | 5w | engineer + risk-counsel merged |
| §194-O TDS auto-deduct + 26AS reconciliation | 6w (start, finish Phase 3) | risk-counsel |

**Why second:** Escrow = engineers leave WhatsApp. Recon = caveman sleep at night. TDS = no §40(a)(ia) disallowance bomb later.

---

### Phase 3 — Trust & Evidence (5 weeks)
**Goal:** Hospital believe what they see. Disputes settle on data, not shouting.

| Feature | Effort | Lens / Source |
|---|---|---|
| Pre-Visit Engineer Dossier (PVED) | 4w | hospital-admin |
| Digital Service Report (DSR) + Aadhaar eSign | 5w | hospital-admin |
| Dispute Defense Vault (auto-evidence collation) | 4w | engineer |
| Dispute Mediation Console + Evidence Pack export | 4w | founder-ops |
| §65B Digital Evidence chain-of-custody (hashing + IPFS-style ledger) | 4w | risk-counsel |
| NABH-ready per-job PDF export | 4w | skeptic-panel #3 |
| AMC-checker upload + digital affidavit at booking | 3w | skeptic-panel #2 |
| Engineer Periodic Re-KYC (DigiLocker + Authbridge) | 7w | risk-counsel |

**Why third:** PVED + DSR + Vault all feed same `evidence_ledger`. Build once, use everywhere.

---

### Phase 4 — Hospital Console & Fleet (6 weeks · realistic 9 weeks)
**Goal:** BME staff actually work in tool. Stop phone-only torture. Open enterprise wallet.

| Feature | Effort | Lens / Source |
|---|---|---|
| Biomedical Coordinator Web Console (Next.js + Supabase RLS) | 6w (realistic 9w) | hospital-admin |
| Equipment Fleet Console + MTBF/MTTR Dashboard | 3w | hospital-admin |
| Code Red Emergency Override (60-min SLA, 3-engineer parallel page) | 4w | hospital-admin |
| Predictive PM Calendar + Auto-Quote | 4w | hospital-admin |
| NABH Evidence Vault (auto-bundle export ZIP) | 3w | hospital-admin |
| Engineer SLA + Weekend Coverage Board | 2w | founder-ops |
| **Master PI Policy ₹10Cr + DPO + DPA template** | 8w (start day 1 of Phase 1) | skeptic-panel #5 |

**Why fourth:** Need Phase 3 evidence + Phase 2 money working first. Web console is moat — phone-only competitor cannot match.

---

### Phase 5 — Growth & Intelligence (5 weeks)
**Goal:** Now safe to push gas pedal. Compound flywheel.

| Feature | Effort | Lens / Source |
|---|---|---|
| Founder Cockpit v2 (cohort + retention + LTV + GMV per vertical) | 3w | founder-ops |
| Risk Score RS0-100 + auto-flag (alert-only first 30 days) | 4w | founder-ops |
| Collusion Graph Detector | 2w | founder-ops |
| Duplicate Account Detector | 2w | founder-ops |
| Job Profitability Score (engineer pre-accept) | 2w | engineer |
| First-job-free promo (cap ₹500 per hospital) | 2w | senior-PM |
| Verified Badge Tiers (Aadhaar / GST / BGC / Pro) | 2w | senior-PM |
| Engineer Profile Completeness Meter | 2w | senior-PM |
| Hindi + Telugu localization + Mixpanel funnels | 5w | senior-PM |
| Bonded-warehouse parts pipeline + tamper QR | 6w | skeptic-panel #4 |

**Why last:** Growth tools useless if fraud unchecked. Risk Score needs feature-store from Phases 1-3 data.

---

## 3. Killed Features (NOT in v0.4)

| Feature | Why kill |
|---|---|
| HIS/HMIS HL7 integration | Hospital IT teams move slow. Sales cycle 9 months. Wait v0.5. |
| Spare-Part Provenance OEM API scan | Bonded warehouse covers 80% of risk. OEM APIs barely exist in India. |
| Treating-Doctor Visibility Card | Need hospital SSO. Phase 4 console first. |
| Engineer Peer Forum + Senior Consult | Premature community. Need 500+ engineers first. We have 30. |
| Parts Marketplace + BNPL | NBFC tie-up = 6 months. Different business. |
| Professional Liability per-engineer policy | Master ₹10Cr policy ships instead — cheaper, faster, same shield. |
| Calendar Sync (Google) | Niche. Multi-route optimizer cover 80%. |
| Save card + UPI autopay AMC renewal | Need AMC churn signal first. Premature. |
| Bundle pricing 10-pack | Top-20% hospitals not yet identified. Phase 5 cohort data first. |
| In-chat photo annotation | Nice-to-have. WhatsApp does it. Wait. |
| Win-back flow 45d dormant | Need 6 months data to know what "dormant" means. |
| Broadcast Comms + WhatsApp blasts | 30 engineers = WhatsApp DM still works. |
| Feature flag + A/B infra | Need >200 users for AB power. Hardcode for now. |
| Filter/sort browse | B2B not Amazon. Few engineers per modality. Defer. |
| Post-service NPS card | Manual founder calls beat NPS at this stage. |
| Reputation Shield + 1-star freeze | Build with arbiter SOP in v0.5. |
| Live Service Bay Camera (continuous video) | 50MB/job bandwidth + storage cost not worth at 30 jobs/week. Photo+vault enough. |
| Multi-hospital Route Optimizer | 1 engineer doing 4 hospitals/day not yet reality. |
| NSDL e-Sign + e-Stamp SHCIL | DSR Aadhaar eSign in Phase 3 cover most. Full e-Stamp wait. |
| AML / STR pipeline | <₹50L/mo GMV not on FIU-IND radar yet. Build hooks, defer pipeline. |
| Invite-3 referral loop | No virality without trust. Phase 5 minimum. |
| Auto-Reconciled GST Bundle (hospital side) | Engineer GST + 3-way recon cover. Bundle is reporting layer, defer. |

---

## 4. Dependency Graph

```
Phase 1 (Audit Log) ──────────┐
                              ├─► Phase 2 (Refund + Recon)
Phase 1 (Consent Ledger) ─────┘
                                       │
                                       ▼
Phase 2 (Escrow) ──► Phase 3 (Dispute Vault + Mediation)
                                       │
Phase 3 (PVED + DSR + §65B) ───────────┤
                                       ▼
                              Phase 4 (Console + NABH Vault)
                                       │
                                       ▼
Phase 4 (Fleet + SLA) ──► Phase 5 (Risk Score + Cockpit)
                                       │
Phase 5 (Risk Score) ──► Collusion + Duplicate detector
```

**Critical chain:** Audit Log → Refund → Escrow → Vault → Console → Risk Score. Break chain anywhere, downstream collapse.

**Parallel tracks (kick off day 1 of Phase 1, not when phase arrives):**
- Master PI Policy ₹10Cr underwriting (insurer takes 6-10 weeks)
- CDSCO representation letter draft (servicing ≠ manufacture under §3(f), Trivitron v. UoI 2022)
- Senior counsel opinion on tortious-interference defence (Mukul Rohatgi tier, ~₹5-10L)
- Trivitron + BPL design-partner LOI outreach (Indian OEMs)

---

## 5. The 7 Must-Haves (Ranked by ROI)

| # | Title | Lens | Effort | Risk killed | Impact |
|---|---|---|---|---|---|
| 1 | Founder Action Audit Log | founder-ops | 1w | Audit-10 gap. Lose dispute legal. Co-founder onboard impossible. | Unlocks everything downstream. 1 week = highest ROI in roadmap. |
| 2 | Three-Way Recon (RZP+CF+GST) | founder-ops | 3w | Silent rupee drift compounds. Round 466 was reactive. | Caveman sleep. Books actually true. |
| 3 | Smart Escrow with Auto-Release | engineer | 3w | Engineers stay on WhatsApp cash forever. | Activation gate. Without this, GMV cap = ₹5L/mo. |
| 4 | DPDP Grievance + Consent Ledger | risk-counsel | 3w combined | ₹250 Cr fine. Safe-harbour loss. | Cheap regulatory shield. |
| 5 | Pre-Visit Engineer Dossier | hospital-admin | 4w | Hospital admin refuse stranger near ₹40L CT. | Unlocks big hospital sales. |
| 6 | Digital Service Report + eSign | hospital-admin | 5w | NABH COP-6 reject. Paper jobsheet lost. | Premium AMC pricing. |
| 7 | Risk Score + Collusion Detector | founder-ops | 6w combined | Free-service-attack. Kickback pairs. Fraud fire later. | Without this, Phase 5 growth = growing the fraud too. |

---

## 6. Sequencing Rationale

- **Phase 1 first** — legal floor is cheap and mandatory. Audit log unlocks every override downstream. Skip = build on sand.
- **Phase 2 before evidence** — money is the wound. Engineers no leave WhatsApp till escrow real. Recon catches drift before it hide in books for 6 months.
- **Phase 3 evidence pipeline shared** — PVED, DSR, Vault, §65B all write to same `evidence_ledger`. Build once. Each lens asks the same thing under different names; we unify.
- **Phase 4 console + fleet** — hospital admin no scale on phone. Web console = enterprise unlock. Need Phase 3 evidence to fill the console screens.
- **Phase 5 growth last** — growing broken system makes break worse. Risk Score needs 3 months of clean Phase 1-4 data to train on. Localization (Telugu) + Mixpanel last because you measure what you trust — and we now trust.

**Each phase unlocks:** P1 = legal cover → P2 = real money → P3 = dispute clarity → P4 = enterprise → P5 = scale.

---

## 7. Execution Risks (what me worry about)

1. **Scope creep — 58 features is too many.** Already cut 22. Will cut more mid-flight. Whoever say "but we also need X" in week 6 gets ignored. Lock list now.
2. **Phase 1 looks small, will eat 4 weeks not 3.** Legal text drafting always slip. DPO appointment paperwork take 10 days alone. Buffer +1 week.
3. **Phase 3 has 32 weeks of work crammed in 5 calendar weeks.** Only works if PVED + DSR + Vault + §65B share schema. If they fork, phase blows up to 8 weeks.
4. **Re-KYC at 7 weeks effort.** Authbridge API integration always late. Engineers HATE re-KYC — churn risk. Soft-launch with grandfather clause for first 50.
5. **BMC Web Console (6 weeks).** This is Next.js app from scratch + RLS + role matrix. Realistically 9 weeks. Hire 1 contractor or it eats founder.
6. **Master PI Policy ₹10Cr.** Insurer underwriting take 6-10 weeks. **Start RFP day 1 of Phase 1**, not Phase 4. Cannot pipeline.
7. **TDS §194-O.** If we ship Phase 2 without TDS deduct, we owe TDS retroactively + 30% expense disallowance. Cannot ship escrow without TDS. Tightly coupled.
8. **Risk Score false positives.** Block legitimate engineer = he go back to WhatsApp forever. Start as alert-only for 30 days, only then auto-block.
9. **Founder bandwidth.** This is 23 weeks of dev. Founder is also sales + ops + support. Need 2 engineers full-time minimum, currently have 0. Hire before Phase 2 or roadmap fictional.
10. **What I'd kill if budget cut 30%:** Predictive PM Calendar, Engineer SLA Board, Profile Completeness Meter, Verified Badge Tiers visual, Code Red (defer to v0.5). Save 8 weeks. Keep money + evidence + console.

**Caveman bottom line:** v0.4 not about features. v0.4 about not dying when scale 10x. Build floor first, ceiling later.

---

## 8. Phase Timeline (calendar view)

| Week | Phase | Engineering | Legal/Insurance/Ops (parallel) |
|---|---|---|---|
| W1-W4 | Phase 1 | Audit log, DPDP, chat lockdown, taxonomy | PI insurance RFP submitted (Tata AIG / Bajaj). CDSCO rep letter drafted. |
| W5-W8 | Phase 2 | Refund + recon + escrow + UPI intent | Counsel opinion ordered (Rohatgi). PI quote received, negotiating. |
| W9-W13 | Phase 3 | Evidence pipeline (PVED + DSR + Vault + §65B + NABH + AMC checker + re-KYC) | DPO appointed. DPA template signed by first 5 hospitals. PI policy bound. |
| W14-W19 | Phase 4 | BMC Web Console + Fleet + Code Red + PM Calendar + NABH Vault + SLA Board | Hire 2 engineers. Trivitron/BPL LOI outreach. |
| W20-W24 | Phase 5 | Cockpit + Risk Score + Collusion + Profitability + First-job-free + Verified Badge Tiers + Profile Meter + Localization + Bonded parts | First super-specialty vertical pilot (dental/IVF/dialysis). |

**Total:** 24 calendar weeks · ~6 months · target completion = late November 2026.

---

## 9. Open Questions for Founder

1. **Hire approval** — 2 full-time engineers for 6 months. ~₹40L cost. OK?
2. **Vertical pick** — dental OR IVF OR dialysis OR ophthalmology? Pick ONE for Phase 5 pilot. Owner-decided procurement matters more than market size at this stage.
3. **Insurer pick** — Tata AIG vs Bajaj Allianz vs ICICI Lombard for the ₹10Cr PI master policy. Need RFP start day 1.
4. **OEM design-partner pick** — Trivitron vs BPL first? Or both parallel? Indian OEMs only — non-Western to avoid AMC overlap.
5. **Legal counsel pick** — Khaitan & Co vs AZB & Partners vs Lakshmikumaran for retainer? Health-regulatory specialty matters more than brand.
6. **First-job-free budget** — ₹500 per hospital × 50 hospitals = ₹25k. OK for Phase 5 cold-start?

---

## 10. Related

- [Skeptic Panel 2026-06-12](../../.claude/projects/-Users-ganeshdhanavath-equipseva-android/memory/project_business_skeptic_panel_2026_06_12.md)
- [Audit-10 founder-admin 2026-06-12](../../.claude/projects/-Users-ganeshdhanavath-equipseva-android/memory/project_audit_10_founder_admin_2026_06_12.md)
- [Audit-9 chat/messaging 2026-06-12](../../.claude/projects/-Users-ganeshdhanavath-equipseva-android/memory/project_audit_9_chat_2026_06_12.md)
- [Round 480 AMC client 2026-06-12](../../.claude/projects/-Users-ganeshdhanavath-equipseva-android/memory/project_round_480_amc_client_2026_06_12.md)
- [v0.3.5 regression smoke 2026-06-12](../../.claude/projects/-Users-ganeshdhanavath-equipseva-android/memory/project_v035_regression_smoke_2026_06_12.md)

🤖 Generated with [Claude Code](https://claude.com/claude-code) on 2026-06-12
