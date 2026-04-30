# EquipSeva — Pending Before Play Store Submission

What's still missing / stubbed / non-functional. Updated 2026-04-30 after PRs #212 (security), #213 (legal docs).

**Quick status (2026-04-30):** Code is shippable. Legal URLs live. Drafts ready for every Play Console form. Real remaining work = 3 design assets + user paste-into-Play-Console + one device E2E test + post-upload SHA-256 swap.

Legend: 🔴 blocker · 🟠 needs attention · 🟡 nice-to-have · ⚪ beyond v1

---

## 🔴 BLOCKERS — still open (NONE are code work)

### Legal / Compliance — hosted URLs
1. ✅ **Privacy Policy URL** — https://equipseva.com/privacy/ (live, DPDP-compliant, covers Supabase/Sentry/Firebase/Razorpay/FCM). *Minor v2 follow-up: §2 should clarify that engineer-side coarse location is foreground only.*
2. ✅ **Terms of Service URL** — https://equipseva.com/terms/ (live).
3. 🟠 **Play Store Data Safety form** — answer key fully drafted in [docs/launch/DATA_SAFETY.md](docs/launch/DATA_SAFETY.md). Copy each section into Play Console manually.
4. ✅ **Razorpay refund policy URL** — https://equipseva.com/refunds/ (live).
5. ✅ DPDP `delete_my_account` + `export_my_data` RPCs shipped (PR #151, #153). User-facing UI live.
6. ✅ Content report / block / mute flow shipped (PR #148, #190).

### Store Listing — design / marketing
7. 🟠 **App title + short + full description** — fully drafted in [docs/launch/STORE_LISTING.md](docs/launch/STORE_LISTING.md). Copy into Play Console.
8. 🔴 **Feature graphic** 1024×500 PNG — DESIGN ASSET. Not yet created.
9. 🔴 **8 phone screenshots** — DESIGN ASSET. Per the v1 scope (Book Repair + Engineer Jobs only, marketplace gated off): suggested set = welcome/auth, role select, home (hospital), home (engineer), repair-job detail, engineer directory, KYC submitted, chat. Need device captures.
10. 🔴 **App icon master 512×512 PNG** — DESIGN ASSET. Current `ic_launcher_foreground.xml` is a placeholder grid mark; Play Console needs a final brand-art PNG.
11. 🟠 **Content rating** (IARC) — answer key fully drafted in [docs/launch/CONTENT_RATING.md](docs/launch/CONTENT_RATING.md). Copy into Play Console.
12. 🟠 **Target audience** declaration — answers in CONTENT_RATING.md (18+, no children's data).
13. 🟠 **Ads declaration** — answer = "No ads in this app." Trivial Play Console toggle.

### Release Signing — needs first Play upload
14. 🟠 **App Signing SHA-256 from Play Console** — paste it back so `EXPECTED_CERT_SHA256` can be wired and `SignatureVerifier` flips from report-only to enforce. Also: append the same SHA-256 to [well-known/.well-known/assetlinks.json](well-known/.well-known/assetlinks.json) + [docs/.well-known/assetlinks.json](docs/.well-known/assetlinks.json) so App Links keep verifying. **A scheduled remote agent is armed for 2026-05-07T03:30Z to open a GitHub issue with the exact paste-instructions** (routine `assetlinks-swap-after-first-aab`).

### Manual device tests
35. 🟠 **Razorpay return deep-link** — `equipseva.com/pay/return` filter declared, assetlinks.json live + Google validator green. Needs end-to-end real-device test on Razorpay test mode.
46. 🟠 **End-to-end Razorpay test-mode flow on real device** — same as above.

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

## SUMMARY — what v1 launch *actually* needs now (2026-04-30)

### 🔴 DESIGN ASSETS — true blockers, need a designer
- **Feature graphic** 1024×500 PNG (item #8)
- **8 phone screenshots** (item #9) — capture from emulator after design pass
- **App icon master** 512×512 PNG (item #10) — current is a placeholder grid mark

### 🟠 PASTE-INTO-PLAY-CONSOLE — drafts ready, ~30 min of clicking
- Store listing copy → [docs/launch/STORE_LISTING.md](docs/launch/STORE_LISTING.md)
- Data Safety form → [docs/launch/DATA_SAFETY.md](docs/launch/DATA_SAFETY.md)
- IARC + target audience + ads → [docs/launch/CONTENT_RATING.md](docs/launch/CONTENT_RATING.md)
- Full runbook → [docs/launch/LAUNCH_CHECKLIST.md](docs/launch/LAUNCH_CHECKLIST.md)

### 🟠 ONE DEVICE TEST — needs a phone + Razorpay test creds
- End-to-end Razorpay test-mode flow with `equipseva.com/pay/return` deep-link verification.

### 🟠 ONE-SHOT POST-UPLOAD
- Paste App Signing SHA-256 from Play Console → CI secret `EXPECTED_CERT_SHA256` + assetlinks.json append. Scheduled remote agent fires 2026-05-07T03:30Z to walk you through it.

### ✅ DONE
- All code work for v1. All RLS / security hardening (PR #212). All legal URLs hosted. All policy + form drafts in `docs/launch/`. assetlinks.json live + Google validator green.

**Code work remaining: NONE for v1.** Next code waves are post-launch (admin moderation queue, managed categories table, engineering quality polish on test/staging accounts).
