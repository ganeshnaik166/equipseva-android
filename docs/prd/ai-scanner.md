# AI Equipment Scanner

**Status:** Draft · Sub-PRD to Master PRD · Owner: Android track (Phase 1–3), iOS track (Phase 4)

One-line description: User taps "Scan equipment" on Home, captures a nameplate photo, and the app identifies brand/model/category via Claude vision then surfaces matching marketplace spare-part listings.

---

## Goals & non-goals

### Goals

- **Supplier match quality.** Reduce the "wrong part ordered" rate by grounding every parts search in a verified brand + model + category triplet, instead of a biomed tech's typo-prone free-text guess.
- **Reduced support burden.** Cut inbound "what part do I need?" WhatsApp messages to the EquipSeva ops team by giving hospital users a self-serve identification path.
- **Faster repair workflows for engineers.** A field engineer arrives on-site, scans the nameplate, and lands on a pre-filtered parts list in under 15 seconds — compressing the identify-to-order loop that today spans multiple calls.
- **Data flywheel.** Every scan becomes a labelled (image → brand/model) datapoint we can eventually use for supplier demand forecasting and for training a cheaper on-device classifier in future phases.

### Non-goals (v1)

- No receipt / invoice scanning. Equipment nameplates only.
- No QR code or barcode fallback in v1. If the device has a QR code, the user photographs it like any other label; we do not special-case decode it.
- No video or live AR overlay. Single still image per scan.
- No offline / on-device model in v1. Every scan requires network.
- No multi-device-in-one-photo handling. The prompt assumes one primary device per image.

---

## Personas & user stories

### Persona 1: Hospital biomed technician

- *As a biomed tech, I want to photograph the nameplate of a failing ventilator so that I can order the correct filter without digging through the manufacturer's PDF manual.*
- *As a biomed tech, I want the scanner to pre-fill the RFQ form with the identified brand and model so that I don't have to retype details I already captured.*

### Persona 2: Field repair engineer

- *As a field engineer on-site at a hospital, I want to scan an unfamiliar device and see compatible spare parts so that I can quote a repair cost before leaving the premises.*
- *As a field engineer, I want my last 20 scans saved under a "Recent scans" list so that I can reorder the same part for a similar device at my next job.*

### Persona 3: Supplier

- *As a supplier, I want incoming scanner-driven leads to include the identified brand/model so that I can respond with an exact-fit quote instead of a generic one.*
- *As a supplier, I want scanner leads flagged as "image-verified" in my RFQ inbox so that I can prioritise them over low-quality text-only queries.*

---

## UX flow

1. User taps the **Scan equipment** tile on Home.
2. App requests camera permission (first time only). On denial, show a "Use gallery instead" fallback.
3. CameraX (Android) / PhotoPicker (iOS) opens. Copy: *"Point at the device's nameplate or model sticker."*
4. User captures or selects a photo.
5. Client downscales to max 1024px on the long side, JPEG q=80.
6. Client shows a loading state ("Identifying equipment…") and calls the `scan-equipment` Edge Function.
7. Edge Function returns `{brand, model, category, confidence}`.
8. Result card renders: identified brand, model, category, and a primary CTA **Find parts**.
9. Tap **Find parts** → deep-links to the marketplace search screen pre-filtered by brand + model + category.
10. Scan is persisted to `equipment_scans` and appears in a **Recent scans** list on the Scanner home.

### Empty state: no match

- Claude returns `confidence < 0.5` or `null` fields.
- Show: *"We couldn't identify this device. Try a clearer photo of the nameplate, or search manually."* with two CTAs: **Retake** and **Search marketplace**.

### Error states

| Error | Trigger | UX |
|---|---|---|
| Bad image | Client-side blur/darkness heuristic fails, or Edge Function returns `IMAGE_UNREADABLE` | Inline message + **Retake** button |
| No network | Client detects offline | *"You're offline. Scans need an internet connection."* — disable capture |
| Rate limit hit | Edge Function returns 429 | *"You've used your 20 scans for today. Try again tomorrow or search manually."* |
| API outage | Edge Function returns 5xx or times out >15s | Fallback: open manual marketplace text search with a toast *"Scanner is temporarily unavailable."* |

---

## Technical architecture

### Mobile client

- **Android:** CameraX `ImageCapture` use case, Compose camera preview. Target API 24+. Downscale via `BitmapFactory` `inSampleSize` + a post-decode matrix scale to ensure longest side ≤ 1024px. Encode JPEG quality 80.
- **iOS (Phase 4):** SwiftUI `PhotosPicker` initially (simpler than AVFoundation custom capture). Same 1024px downscale, same JPEG q=80.
- **Upload format:** multipart/form-data to the Edge Function, not base64 — binary is ~33% smaller on the wire.

### API proxy: Supabase Edge Function `scan-equipment`

- Accepts: `multipart/form-data` with one image field; auth via Supabase JWT.
- Forwards image to Anthropic's Claude API, model **`claude-sonnet-4-6`**, using the vision message format.
- Prompt (stub): *"You are identifying medical equipment from a nameplate photo. Return JSON with keys brand, model, category, confidence (0–1). If unreadable, return nulls. No prose."*
- Parses Claude's JSON response, validates schema, persists to `equipment_scans`, returns result to client.
- Latency budget: p95 ≤ 6s end-to-end.

### API key storage

- Anthropic API key lives in Supabase Edge Function environment (Supabase Vault). **Never** bundled in the APK/IPA.
- Key is on a separate Anthropic billing account created at console.anthropic.com — the owner's Max subscription does **not** cover API usage and must not be used for this.

### Price enrichment

- Claude returns identification only. The Edge Function then queries the app's own `spare_parts` table (`WHERE brand ILIKE :brand AND model ILIKE :model`) to attach real prices and listing IDs to the response.
- **The LLM is not trusted to state prices, availability, or supplier names.** All commercial data comes from our own Postgres.

### Rate limiting

- Per-user daily cap: **20 scans / 24h rolling window**, enforced in the Edge Function via a count query against `equipment_scans`.
- Per-IP soft cap as a second line of defence against a compromised JWT.

---

## Data model

### New table: `equipment_scans`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `user_id` | `uuid` FK → `auth.users.id` | Not null |
| `image_url` | `text` | Supabase Storage path, private bucket |
| `identified_brand` | `text` | Nullable (no-match case) |
| `identified_model` | `text` | Nullable |
| `identified_category` | `text` | Nullable |
| `confidence` | `numeric(3,2)` | 0.00–1.00 |
| `claude_latency_ms` | `integer` | For performance SLO tracking |
| `created_at` | `timestamptz` | `now()` default |

### RLS policies

- `SELECT`: `user_id = auth.uid()` — users see only their own scans.
- `INSERT`: disallowed from client. All inserts go through the Edge Function (service role).
- `UPDATE` / `DELETE`: disallowed from client.

### Storage bucket: `equipment-scan-images`

- Private. Signed URL access only, 1-hour expiry.
- Lifecycle rule: auto-purge objects older than **30 days** (see privacy risk below).

---

## Cost model

Claude Sonnet 4.6 vision pricing (as of 2026-04-23): **$3 / M input tokens, $15 / M output tokens**.

Per-scan math:

| Item | Tokens | Cost |
|---|---|---|
| Image input (1024px, vision encoding) | ~1,500 | $0.0045 |
| Prompt text | ~100 | $0.0003 |
| JSON output | ~200 | $0.0030 |
| **Total / scan** | | **~$0.0078** |

Volume projections:

| Daily scans | Daily cost | Monthly cost (30d) |
|---|---|---|
| 100 | $0.78 | $23.40 |
| 1,000 | $7.80 | $234.00 |
| 10,000 | $78.00 | $2,340.00 |

### Unit economics sanity check

- Assume a scan leads to a ₹2,000 part purchase, EquipSeva platform fee 10% = ₹200 revenue (~$2.40 at ₹83/USD).
- Break-even conversion rate = $0.0078 / $2.40 = **0.33%**.
- Any scan→order conversion above ~1% makes the feature comfortably profitable even before retention uplift is counted.

---

## Rollout plan

| Phase | Scope | Exit criteria |
|---|---|---|
| **1** | Android placeholder tile on Home — taps open a "Coming soon" screen. Shipped in PR #100. | Tile visible behind no flag; analytics event fires on tap. |
| **2** | CameraX capture flow + mocked result (hardcoded brand/model, no Claude call). | Capture → downscale → mock result renders; deep-link to marketplace works. |
| **3** | `scan-equipment` Edge Function live + real Anthropic integration. Gated behind remote feature flag `ai_scanner_enabled`. Rollout 10% → 50% → 100% over 2 weeks. | p95 latency ≤ 6s; error rate < 2%; API spend tracking in place. |
| **4** | iOS parity (PhotosPicker), price enrichment from `spare_parts`, full analytics dashboard. | iOS build in TestFlight; price card renders on result; dashboard live. |

---

## Success metrics

- **Scans per day** — north-star volume metric. Target: 500/day by end of Phase 3 rollout.
- **Scan → parts-search conversion** — % of scans where user taps **Find parts**. Target: ≥ 60%.
- **Scan → order conversion** — % of scans that result in a paid order within 7 days. Target: ≥ 3% (comfortably above the 0.33% break-even).
- **Average Claude latency** — p50 and p95 of `claude_latency_ms`. SLO: p95 ≤ 5s.
- **Monthly Anthropic API spend** — tracked against a budget alert at $500/month in Phase 3.
- **Retention uplift** — 30-day retention of users with ≥1 scan vs. matched cohort without. Target: +5 percentage points.
- **No-match rate** — scans returning null identification. Target: < 15%. Above that, prompt tuning or image-quality UX needs rework.

---

## Open questions & risks

### Risks

- **Hallucination risk.** Claude may confidently misidentify ("Siemens Somatom" when the device is actually a Toshiba Aquilion). Mitigations: (a) always show `confidence`, (b) require user to confirm before deep-linking to parts, (c) never auto-submit RFQs from scan output, (d) track supplier-reported mis-ID rate.
- **Privacy — PHI in frame.** Hospital environments frequently have patient info on whiteboards, wristbands, or charts that could enter frame. Mitigations: (1) privacy policy update stating images are retained 30 days then purged, (2) bucket is private and not indexed, (3) in-app copy warns user to frame only the device nameplate, (4) no image is ever sent to any party other than Anthropic and our own Supabase.
- **Anthropic API outage.** Mitigation: Edge Function circuit breaker — after 3 consecutive 5xx in 60s, return a graceful-degrade response; client falls back to marketplace text search.
- **Store policy risk.** Google Play and App Store both require AI-generated content disclosures. Mitigation: (a) result card labelled "AI-identified — please verify"; (b) app listing updated with AI-use disclosure; (c) no claim that identification is medically authoritative.
- **Cost runaway.** Malicious user floods the endpoint. Mitigation: 20-scan daily cap + per-IP cap + budget alert.

### Open questions

- Multipart vs. base64 upload — PRD parent text said base64, this sub-PRD proposes multipart. Confirm with backend dev.
- Do we persist the image at all, or hash-only? Retention is a privacy cost; deletion means we lose the training-data flywheel. Recommendation: persist 30 days, then purge.
- Should suppliers see the raw scan image attached to an RFQ, or only the identified text? Default: text only, image stays private to the scanning user.
- Is 20/day the right cap, or should engineers on a field visit get a higher tier (say 50/day)?

---

## Dependencies & owners

| Area | Owner | Dependency |
|---|---|---|
| Android client (CameraX, Compose UI) | Android dev | Phase 1 shipped; Phase 2–3 next |
| iOS client (PhotosPicker, SwiftUI UI) | iOS dev | Blocked on Phase 3 Edge Function being stable |
| `scan-equipment` Edge Function | Backend dev | Supabase Vault access; Anthropic API key |
| `equipment_scans` migration + RLS | Backend dev | Supabase migration review |
| Storage bucket + lifecycle rule | Backend dev | 30-day purge policy sign-off from legal |
| Privacy policy update | Legal | Must ship **before** Phase 3 public rollout |
| Anthropic billing account | Finance | New account at console.anthropic.com, separate from the owner's Max subscription (Max does not cover API usage) |
| Remote feature flag `ai_scanner_enabled` | Android dev | Existing flag system |
| Analytics dashboard | Android dev + data | Phase 4 |

---

## Change history

v0.1 · 2026-04-23 · Initial draft
