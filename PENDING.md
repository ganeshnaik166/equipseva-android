# EquipSeva — Pending Before Play Store Submission

Comprehensive scan of what's still missing / stubbed / non-functional. Ordered by severity. Updated 2026-04-24.

Legend: 🔴 blocker · 🟠 needs attention · 🟡 nice-to-have · ⚪ beyond v1

---

## 🔴 BLOCKERS — Play Store will reject without these

### Legal / Compliance
1. **Privacy Policy URL** — Play requires a public URL. You must host one (single-page site, even a Notion page works). Needs to cover: Supabase, Sentry, Firebase Analytics, Crashlytics, Razorpay, FCM, location usage on KYC.
2. **Terms of Service URL** — linked from settings + signup.
3. **Play Store Data Safety form** — declare every field we collect: email, phone, full name, Aadhaar #, KYC docs, location (shipping), device ID (FCM), payment info (via Razorpay).
4. **DPDP (Digital Personal Data Protection, India) compliance** — user consent screen, data-deletion endpoint (`DELETE /me` in Supabase RPC), right-to-export flow. *Zero of this exists today.*
5. **Razorpay refund policy URL** — required by the gateway + RBI regulations. Customer-facing refund terms.
6. **Content policy** — user-generated chat/listings need a report + block flow. **Not built yet.** Play flags apps without this.

### Store Listing
7. **App title** (max 30 chars) + **short description** (max 80) + **full description** (max 4000).
8. **Feature graphic** 1024×500 PNG — marketing banner.
9. **8 phone screenshots** minimum — covering auth, home, marketplace, cart, checkout, order detail, chat, KYC. Needs design pass from your current branch.
10. **App icon** — you have `ic_launcher_foreground.xml` as a vector grid mark. Needs review: is this final brand art, or placeholder? Adaptive icon with 512×512 master PNG required.
11. **Content rating** questionnaire (IARC) — Play walks you through it.
12. **Target audience** declaration + privacy note for under-18 users.
13. **Ads declaration** — we don't show ads; must still declare.

### Release Signing
14. **App Signing SHA-256 from Play Console** — after you upload the first APK, Play shows you this. Paste it back → I wire `EXPECTED_CERT_SHA256` so anti-tamper activates on installed builds.

---

## 🟠 NEEDS ATTENTION — users will hit these on day 1

### Stubs still in code (will ship broken if released)
15. **Notifications inbox** (`NotificationsScreen.kt`) — shipping 3 hardcoded demo rows ("New bid received", "Order shipped", "Repair job completed"). *No backend table, no realtime, no mark-read.* Design branch converts it to a settings screen instead — pick one: keep inbox (needs backend) or replace with settings (needs backend for preferences to persist). **Cannot ship the current demo rows.**
16. **Scan Equipment AI** (`ScanEquipmentViewModel.kt`) — returns a `mockResults.random()`. UI even says "Phase 2 preview — identification is mocked." Either wire real Claude Vision API *or* hide the entry point for v1.
17. **Cart sync** — Room-only, no server reconcile (`CartRepository.kt` comment: "will reconcile with Supabase in Phase 3"). User loses cart on reinstall / device switch. Low severity if we document the limitation.
18. **Photo-upload outbox handler** — 3 of 4 outbox kinds wired (chat, bid, status). `OutboxKinds.PHOTO_UPLOAD` declared but no handler. Engineer uploading a repair photo on weak network = upload fails silently with no retry.
19. **Cart outbox kind** — no offline cart mutations queued. Adding to cart offline = silent drop.

### Flows users will discover are missing
20. **Order rating flow** — you rate repair jobs; you can't rate a spare-part order / supplier. Trust loop broken for marketplace.
21. **Review / report content** — no way to flag a bad listing, spam chat message, or abusive behavior. **Play Store content policy requires this.**
22. **Block / mute user** — same policy concern.
23. **Delete account** — DPDP requires this. No UI, no RPC.
24. **Export my data** — DPDP right-to-portability. No UI, no RPC.
25. **Change email / phone** — Profile shows them but no edit flow.
26. **Change password** — no "change password" UI (forgot password exists for signed-out state only).
27. **Mark all notifications read** — moot if #15 is unresolved.
28. **Chat: delete message** — not built.
29. **Chat: edit message** — not built.
30. **Chat: typing indicator** — stubbed as `isTyping = false` in ChatScreen (design branch).
31. **Order cancel reason** — cancellation exists but no free-text reason collected.
32. **KYC re-upload** — if rejected, flow to re-submit isn't clear.
33. **KYC status transitions** — "submitted → under review → verified/rejected" transitions not all visualized.
34. **RFQ bid accept message** — after accepting, buyer doesn't automatically land in chat with supplier.
35. **Razorpay return deep-link** — `https://equipseva.com/pay/return?order_id=…` filter declared; never device-tested end-to-end. One cold-start bug away from a failed-payment support storm.

### Push notification send policies
36. **Server-side send rules** — FCM plumbing is ready (4 channels, device-token upsert). Nothing actually sends notifications. Nobody gets told when their order ships, their bid wins, their RFQ gets a quote. **Needs an Edge Function + DB trigger per event.**
37. **Deep-link from notification** → specific screen — partial (order_id only).
38. **Quiet hours / Do Not Disturb respect** — not implemented.
39. **Per-category mute** — shown in settings UI but doesn't persist (design branch local state only).

### Backend / Edge Functions
40. **Notifications backend** — table + RLS + realtime + FCM sender. Zero.
41. **DPDP: `delete_my_account` RPC** — needed.
42. **DPDP: `export_my_data` RPC** — needed.
43. **Content moderation moderation table** + RPC + admin queue — needed for #21-22.
44. **Play Integrity verifier Edge Function** — we collect the token client-side (see `PlayIntegrityClient.kt`), but no server-side verifier.

---

## 🟡 NICE TO HAVE — can ship v1 without, add post-launch

### Engineering quality
45. **Compose UI smoke test** — auth → home → cart → checkout. Audit flagged no instrumented coverage.
46. **End-to-end Razorpay test-mode flow** on a real device.
47. **Crash-free ≥ 99.5% SLO monitoring** — Sentry is wired, nobody's looking.
48. **Room destructive-migration fallback** — today a schema bump wipes local cache/outbox. Needs real migration paths before v2.
49. **Cold-start measurement baseline** — never measured.
50. **APK size budget** — not set; currently 23 MB which is fine.
51. **R8 mapping upload to Sentry** — produces mapping.txt but doesn't upload. Un-deobfuscated stack traces = slower incident response.

### UX polish
52. **Empty states with CTAs** — most lists have plain "nothing here" text; could offer first-action buttons.
53. **Skeleton loaders vs CircularProgressIndicator** — skeleton is better UX on lists.
54. **Pull-to-refresh on Conversations list** — realtime handles it but users expect the gesture.
55. **Conversations search** — not implemented.
56. **Onboarding / first-run tour** — no welcome coaching.
57. **Tablet / large-screen layouts** — minimum responsive fixes shipped (`rememberAdaptiveWidth`/`maxContentWidth` in `designsystem/AdaptiveWidth.kt`; marketplace manufacturer grid is 2/3/4 cols by width; marketplace search results + repair jobs list cap at 840dp). Compose bottom-nav/master-detail still TODO.
58. **Dark mode** — theme exists, not stress-tested across all screens.

### Seed data / Content
59. **Demo spare-part catalog** — empty DB = "No parts yet" as first impression.
60. **Test hospital + engineer accounts** — manual DB inserts today.
61. **Equipment categories / brands** — currently hardcoded enums; consider a managed table so you can add without app release.

---

## ⚪ BEYOND v1 SCOPE (per PRD §12 — supplier/manufacturer/logistics are post-launch)

62. Supplier screens (my listings, stock alerts, supplier orders, supplier RFQs, add listing) exist and are polished but not planned for v1 rollout.
63. Manufacturer screens (analytics, lead pipeline, RFQs assigned) — same.
64. Logistics screens (pickup queue, active deliveries, completed today) — same.
65. AI equipment scan PRD drafted (#103) — Phase 3 work.

---

## SUMMARY — what v1 launch *actually* needs

**You MUST do (cannot ship without):**
- Privacy policy + Terms of service URLs (legal)
- Data Safety form (Play Store)
- Razorpay refund policy (gateway requirement)
- Report / block flow (Play content policy) — **code + backend**
- App title / description / 8 screenshots / feature graphic (store listing)
- Either finish the Notifications inbox backend **or** strip it out for v1
- Either finish the AI scan **or** hide the Scan entry point for v1

**I'll build when you say go:**
- Report / block UI + backend
- Delete account + export data (DPDP)
- Notifications backend if you decide "ship it"
- Hide Scan entry point if you decide "hide for v1"
- Order rating flow
- Change password / change email UI
- Push notification send policies
- R8 mapping upload to Sentry

**You MUST provide externally (I can't fabricate):**
- App Signing SHA-256 (after first Play Console upload)
- Screenshots (design output)
- Policy copy (legal review)
- App icon final artwork (if current placeholder isn't final)

---

## The hard question

**Realistic timeline to a Play-Store-approved build:**
- With legal help: 1 week (privacy + terms + data-safety + DPDP)
- With design help: 1 week (screenshots + icon polish)
- With me shipping the content-policy code (report/block/delete) + trimming stubs: 2-3 days
- Play review itself: 1-7 days

**Fastest path:** 2 weeks to submission, 2-3 weeks to approved.
