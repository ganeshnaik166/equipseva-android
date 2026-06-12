# Phase 5 Vertical Pick — DENTAL

> **Source:** 4-perspective deep-dive workflow (`wjk6fv3hz`) comparing dental / IVF / dialysis / ophthalmology against EquipSeva Phase 5 fit criteria.
>
> **Drafted:** 2026-06-12 · Awaiting founder sign-off.

## Scorecard

| Vertical | TAM (serviceable AMC) | Class A/B share | Procurement | Engineers | Avg ticket | Crit-care risk | Reg risk | Phase 5 fit |
|---|---|---|---|---|---|---|---|---|
| **Dental** | ₹3,500-4,200 Cr | 55-65% | Easy single-owner | Thin | ₹3-15k call / ₹60k-1.5L AMC | LOW | MED (AERB) | **8/10** |
| **IVF** | ₹1,800-2,400 Cr | 85-90% | Med corporate | Almost none | ₹15-50k call / ₹2-15L AMC | EXTREME | HIGH | 3/10 |
| **Dialysis** | ₹60-80 Cr (after C/D block) | 20-25% | Hard government | Almost none | ₹8-25k call / ₹50k-1.5L AMC | EXTREME | HIGH | 2/10 |
| **Ophthalmology** | ₹600-800 Cr (diagnostic carve-out) | 70-75% | Easy single-owner | Moderate | ₹5-25k call / ₹15-50k/unit AMC | MED | LOW | **8/10** |

## The pick — DENTAL

Why dental beats ophthalmology (both tie 8/10):

- **TAM 5× bigger** — ₹3,500 Cr vs ₹600-800 Cr serviceable AMC market
- **One LinkedIn warm intro to Dr Amarinder Singh Dhaliwal (Clove Dental CEO) unlocks 715 clinics** = instant ARR floor of ₹4-6 Cr (715 × ₹60k AMC × 15% take-rate)
- **AMC renewal cycle Apr-Jun** aligns to Indian financial year → natural cohort lock-in, predictable cash
- **Lowest jail risk** of all 4 verticals (worst case: rescheduled cleaning, vs IVF embryo loss / dialysis patient death)
- **Engineer gap = opportunity** — biomed grad + 2-week dental micro-training, bill ₹800-1,200/hr on ₹430 base
- **Competitive whitespace real** — Dentalkart/Dentkart sell parts not service; OEM service slow + expensive; freelancer WhatsApp has no GST + no SLA. Our wedge = GST invoice + SLA + payout rail

Ophthalmology loses 2 points to dental because surgical exclusion (phaco, YAG laser) cuts 25% wallet + Zeiss/Heidelberg are sticky on OCT/fundus AMCs. Dental has no equivalent surgical band — chair / autoclave / compressor / RVG are all third-party serviceable.

## Runner-up — OPHTHALMOLOGY (Phase 5B)

Add ophthalmology after dental hits **₹5 Cr ARR run-rate AND 1,500 active clinics** (target Month 9-12). Engineer pool transfer is easy — biomed + dental engineers cross-train to slit lamp / autorefractor / tonometer in 3 weeks. Same single-owner ICP, same WhatsApp procurement style, same GST-invoice wedge. Carve-out diagnostic only — REFUSE phaco/YAG/OR scope in T&C. AIOS February conference = entry event.

## The AVOID — DIALYSIS

**Skip dialysis. Maybe forever.** Three independent killers:

1. **Skeptic-rule #6** hard-blocks Class C dialysis machines (r486 server-side enforcement); only commodity RO + chair + scale remain
2. **Critical-care risk EXTREME** — RO chloramine breakthrough or air embolism kill patient mid-session. Tirupur 2002 killed 35. Founder personally non-bailable
3. **Channel broken** — NephroPlus + Apollo locked to Fresenius/Nipro direct field-force (sub-4-hr SLA we can't match). PMNDP needs GeM-Gold + ₹1-5 Cr EMD we don't have. Ion Exchange owns 60% of RO ancillary

**IVF also skip Phase 5** — beautiful math, broken ops. Engineer pool ~150-250 humans national, all on Vitrolife / CooperSurgical non-compete. Defer to Phase 7-8 or pivot to SaaS-for-OEM angle.

## Next 30 days — Dental Playbook

### Action 1 — Anchor pilot: Clove Dental Gurgaon (Week 1-2)

LinkedIn warm intro to Dr Amarinder Singh Dhaliwal (CEO, founder). Backup: cold to procurement@clovedental.in. Target = 1-city pilot (Gurgaon HQ, 40-60 Clove clinics).

**Outreach script**:

> "Dr Dhaliwal — EquipSeva runs a GST-invoice + SLA-backed third-party AMC marketplace for dental Class A/B equipment (chair, autoclave, compressor, suction, RVG). Single Gurgaon pilot. We absorb engineer cost, you measure uptime + cost-per-clinic vs current OEM AMC. 60-day trial, no lock-in. 20 min call this week?"

### Action 2 — Equipment focus list (Week 1)

- **IN scope**: dental chair, autoclave, compressor, suction, hand-piece, light-cure, scaler, ultrasonic cleaner, intra-oral camera
- **OUT of scope (v0.4)**: RVG sensor (AERB), OPG, CBCT, laser
- Add RVG via AERB-RSO consultant partnership in v0.5 only

### Action 3 — Pricing strategy (Week 2)

| Tier | Price |
|---|---|
| Single repair ticket | ₹1,500-8,000 |
| AMC bundle 2-chair clinic | ₹55,000/yr (10-15% under OEM ₹70-80k) |
| AMC bundle premium clinic | ₹1,30,000/yr |
| Take-rate AMC | 15-18% |
| Take-rate repair | 22-25% |

Composition-scheme invoice template for unregistered clinics (~40% of single-owner).

### Action 4 — Engineer onboarding (Week 2-4)

- Recruit 8 biomed grads in Delhi-NCR
- 2-week dental micro-training: chair upholstery, hand-piece bearing swap, compressor servicing, autoclave gasket
- Partner with 1 ex-Confident Dental / ex-A-dec service manager as training lead (target CTC ₹18-22L)

### Action 5 — Partnership wedge (Week 3-4)

- Approach **Indian Dental Association (IDA)** central council for SMB acquisition channel — bundle EquipSeva referral into IDA membership benefit
- Parallel: Sabka Dentist Mumbai cold-email founders Vikram Vora + Dr Parth Vora for Pilot #2 lead-in
- Skip Apollo White first 12 months — too bureaucratic

## Top 3 risks

1. **Clove says no or stalls 90+ days** — Single-anchor risk. Mitigate: parallel-track Sabka Dentist Mumbai outreach Week 1 (not Week 5). Two-shot anchor strategy.
2. **AERB radiation creep** — Clinic asks EquipSeva for RVG service Day 1, engineer touches radiation equipment without AERB clearance → CDSCO/AERB notice + ₹2-10L penalty + criminal exposure. Mitigate: hard server-side block RVG/OPG/CBCT category in r486 taxonomy. Founder personally enforces. No exception.
3. **Ticket volume miss** — Mid-tier ₹3-15k tickets need 8,000-12,000 calls/yr for ₹5 Cr GMV. If engineer productivity misses (target 4 calls/day/engineer), unit econ breaks. Mitigate: weekly engineer utilization dashboard from Day 1, AMC-bundle push (recurring) over reactive repair (lumpy).

## Top dental chains in India (decision-makers identified)

| Chain | Size | Decision-maker | Contact path |
|---|---|---|---|
| **Clove Dental** | 715 clinics, 26 cities, ₹378 Cr FY25, backed by Investcorp + QIA | VP-Operations / Head of Clinic Infrastructure (Gurgaon HQ) | LinkedIn → Dr Amarinder Singh Dhaliwal (founder) or procurement@clovedental.in |
| **Sabka Dentist / MyDentist** | ~115 clinics, ₹60 Cr FY25, backed by Asian Healthcare Fund | COO / Head of Clinic Operations (Mumbai HQ Andheri East) | Cold to founders Vikram Vora + Dr Parth Vora |
| **Apollo White Dental** | ~70+ tier-1 clinics, part of Apollo Hospitals | Head of Procurement (Apollo Health & Lifestyle Chennai) | vendor.apollohospitals.com — 8-14 week onboarding cycle (skip for first 12 months) |

## Ship dental. Lock Clove. Move.

🤖 Vertical analysis generated 2026-06-12 via Workflow `wjk6fv3hz`
