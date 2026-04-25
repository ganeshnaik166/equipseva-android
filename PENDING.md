# EquipSeva — Pending Before Play Store Submission

What's still missing / stubbed / non-functional. Updated 2026-04-25 after PRs #148–#195 cleared the code blockers.

Legend: 🔴 blocker · 🟠 needs attention · 🟡 nice-to-have · ⚪ beyond v1

---

## 🔴 BLOCKERS — still open (NONE are code work)

### Legal / Compliance — needs hosted URLs
1. **Privacy Policy URL** — Play requires a public URL. Single-page Notion/site fine. Must cover Supabase, Sentry, Firebase Analytics, Crashlytics, Razorpay, FCM, location-on-KYC.
2. **Terms of Service URL** — linked from settings + signup.
3. **Play Store Data Safety form** — declare every field collected: email, phone, full name, Aadhaar #, KYC docs, location (shipping), device ID (FCM), payment info (Razorpay).
4. **Razorpay refund policy URL** — gateway / RBI requirement. Customer-facing refund terms.
5. ✅ DPDP `delete_my_account` + `export_my_data` RPCs shipped (PR #151, #153). User-facing UI live.
6. ✅ Content report / block / mute flow shipped (PR #148, #190).

### Store Listing — design / marketing
7. **App title** (≤30 chars) + **short description** (≤80) + **full description** (≤4000).
8. **Feature graphic** 1024×500 PNG.
9. **8 phone screenshots** minimum — auth, home, marketplace, cart, checkout, order detail, chat, KYC.
10. **App icon** — `ic_launcher_foreground.xml` is currently a vector grid mark. Confirm final brand art; provide 512×512 master PNG for adaptive icon.
11. **Content rating** questionnaire (IARC) — answered in Play Console.
12. **Target audience** declaration + privacy note for under-18.
13. **Ads declaration** — none, but must declare.

### Release Signing — needs first Play upload
14. **App Signing SHA-256 from Play Console** — paste it back so `EXPECTED_CERT_SHA256` can be wired and `SignatureVerifier` flips from report-only to enforce.

### Manual device tests
35. **Razorpay return deep-link** — `equipseva.com/pay/return` filter declared, app-link assetlinks.json prepared (PR #152). Needs end-to-end real-device test on Razorpay test mode.
46. **End-to-end Razorpay test-mode flow on real device** — same as above.

---

## 🟢 SHIPPED THIS SESSION (was 🔴/🟠/🟡)

| # | Item | PR |
|---|------|----|
| 15 | Notifications inbox (real backend + realtime + mark-read + mark-all-read) | #178 |
| 16 | Hide Scan-AI for v1 | #155 |
| 17 | Cart server sync (cart_items table + outbox handler + bootstrap) | #188 |
| 18 | Photo-upload outbox handler | #163 |
| 19 | Cart_mutation outbox kind | #161 |
| 20 | Buyer rating for spare-part suppliers | #162 |
| 21 | Content report flow extended to listings/RFQ/jobs | #190 |
| 22 | Block user from chat | #148 |
| 23 | Delete account (DPDP) | #151 |
| 24 | Export my data (DPDP) | #153 |
| 25 | Change email from Profile | #160 |
| 26 | Change password from Profile | #156 |
| 27 | Mark all notifications read | #178 |
| 28 | Chat soft-delete | #154 |
| 29 | Chat edit message (15 min window) | #157 |
| 30 | Chat typing indicator (Realtime Broadcast) | #170 |
| 31 | Order cancel reason | #159 |
| 32 | KYC re-upload flow for rejected | #166 |
| 33 | KYC status timeline on Verification screen | #169 |
| 34 | RFQ bid accept opens chat with supplier | #165 |
| 36 | Server-side FCM push send + per-event triggers | #183 #192 |
| 37 | Deep-link from notification tap to screen | #195 |
| 38 | Quiet hours / DND | #182 |
| 39 | Per-category push mute persistence | #173 |
| 40 | Notifications backend (table + RLS + realtime) | #178 |
| 41 | DPDP delete RPC | #151 |
| 42 | DPDP export RPC | #153 |
| 44 | Play Integrity verifier Edge Function + client wiring | #186 #193 |
| 45 | Compose UI smoke test | #179 |
| 47 | Sentry session tracking + user_id bridge | #194 |
| 48 | Real Room migrations (no destructive fallback) | #175 |
| 49 | Cold-start telemetry | #187 |
| 50 | APK size budget guardrail (28 MB) | #189 |
| 51 | R8 mapping upload to Sentry | #164 |
| 52 | Empty-state CTAs on key lists | #172 |
| 53 | Skeleton loaders | #176 |
| 54 | Pull-to-refresh on Conversations | #171 |
| 55 | Conversations search | #174 |
| 56 | First-run tour after sign-up | #177 |
| 57 | Tablet / large-screen layouts | #184 |
| 58 | Dark mode stress-test | #185 |
| 59 | Demo spare-part catalog seed | #181 |
| — | Storage bucket hardening (avatars / chat-attach / repair-photos) | #191 |

---

## 🟡 NICE TO HAVE — defer post-launch

43. **Content moderation admin queue** — `content_reports` table exists; needs an admin-side review UI. Out of scope for the Android app (separate admin web tool).
60. **Test hospital + engineer accounts** — manual DB inserts today.
61. **Equipment categories / brands** — currently hardcoded enums; consider a managed table to add without app release.

---

## ⚪ BEYOND v1 SCOPE (per PRD §12)

62. Supplier screens (my listings, stock alerts, supplier orders, supplier RFQs, add listing) — exist but not v1.
63. Manufacturer screens (analytics, lead pipeline, RFQs assigned) — same.
64. Logistics screens (pickup queue, active deliveries, completed today) — same.
65. AI equipment scan — Phase 3 work.

---

## SUMMARY — what v1 launch *actually* needs now

**Cannot code-ship — must come from outside:**
- Privacy policy + Terms of service URLs (legal)
- Razorpay refund policy URL (legal + gateway)
- Data Safety form answers (Play Console)
- Store listing copy (title / short / full description)
- Feature graphic + 8 screenshots + final app icon (design)
- IARC content rating + target-audience + ads declaration (Play Console)

**Manual testing — needs a real device + Razorpay test creds:**
- End-to-end Razorpay test-mode + return-deep-link flow

**One-shot wiring after first Play upload:**
- Paste App Signing SHA-256 → set `EXPECTED_CERT_SHA256` in CI secrets → flip `SignatureVerifier` to enforce.

**Code work remaining: NONE for v1.** Next code waves are post-launch (admin moderation queue, managed categories table, engineering quality polish on test/staging accounts).
