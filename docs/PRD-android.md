# EquipSeva Android — Product & Design Brief

**Version:** 1.0 · **Date:** 2026-04-19 · **Owner:** Ganesh
**Purpose:** Hand off to a design tool / designer (including Claude-design) to generate the Android mobile app UI. This document is the single source of truth for Android screens, flows, components, and visual direction.

---

## 0. TL;DR for the designer

Design a **Material 3** Android app for **Indian hospital field engineers** (primary) and **hospital admins** (secondary). Brand color is **medical green `#0B6E4F`**. The engineer uses it one-handed in the field (hospital corridors, poor lighting, gloves sometimes on). The hospital admin uses it at a desk as a lighter complement to the web dashboard. English-only at launch. Min Android 8 (SDK 26). Target Android 15 (SDK 35). Compose. No tablet layout v1.

**Tone:** calm, competent, medical-professional. Not playful, not consumer-flashy. Think *Swiggy for ops* meets *Practo for serious work*.

---

## 1. Product context

**EquipSeva** is the operating layer for India's medical-equipment ecosystem. It combines:
- **Marketplace** for spare parts (Amazon-style buyer flow)
- **Repair dispatch** for hospital engineers (Urban-Company-style job flow)
- **Native UPI billing** via Razorpay

One Supabase backend feeds four surfaces: Web (Next.js), **Android (this doc)**, iOS, SEO site.

### The pitch
> "Amazon for medical equipment parts + Urban Company for hospital engineers + Razorpay-native billing, built for Indian hospitals."

### Why Android matters
- India is Android-dominant (~95% of field engineers).
- Engineers work off-desk — mobile-first, offline-tolerant.
- Hospital admins use web primarily; mobile is for tracking on the move.

---

## 2. Personas (Android)

### 2.1 Field engineer — PRIMARY
- **Name shorthand:** Ravi, 32, Chennai. 8 years experience repairing CT/MRI/ECG machines.
- **Device:** Redmi Note 12, ₹12k-class, Android 13, 4GB RAM, patchy 4G.
- **Context:** Inside hospital basements, equipment rooms, ambulances. Gloves sometimes on. One-handed use.
- **Top jobs:**
  1. See nearby available jobs
  2. Read job details (equipment model, hospital, issue)
  3. Place bid (₹ amount + ETA)
  4. Navigate to site (Maps handoff)
  5. Check in / check out with photos
  6. Chat with hospital requester
  7. Upload KYC docs to get verified
  8. See earnings + request payout
- **Pains:** small buttons, too-tall forms, flaky networks, multi-step flows that lose state.

### 2.2 Hospital admin — SECONDARY
- **Name shorthand:** Priya, 38, biomedical coordinator at a 200-bed hospital.
- **Device:** mid-tier Samsung, Android 14, steady Wi-Fi.
- **Context:** Walking the wards; desk work happens on web.
- **Top jobs:**
  1. Raise a repair request on the go
  2. Track an existing repair (status, ETA, engineer)
  3. Track a parts order
  4. Approve/reject an engineer's bid
  5. Message the engineer
  6. Reorder a part she's bought before
- **Pains:** doesn't want to re-learn the web dashboard; wants a simpler "status + action" view.

### 2.3 Out of scope (v1 Android)
No app for supplier, manufacturer, admin, logistics. No tablet. No iPad-analog layout.

---

## 3. Design principles

1. **Engineer-first.** If a decision helps the engineer but hurts the admin slightly, engineer wins.
2. **Glanceable.** Primary screens answer one question in under 2 seconds: *"What do I do next?"*
3. **Offline-tolerant.** Every write (bid, status change, photo) queues locally and syncs; UI never blocks on network.
4. **Large hit targets.** 48dp minimum, 56dp for primary actions. Gloves-on friendly.
5. **High contrast, calm color.** Status colors have meaning (green = good, amber = pending, red = blocked). Everything else is neutral grey with brand-green accents.
6. **One primary action per screen.** Secondary actions live in overflow or below the fold.
7. **Respect the Indian network.** Skeletons, not spinners. Optimistic UI for bids, messages, status flips.
8. **Material 3, native.** Don't invent. Use `FilledButton`, `NavigationBar`, `TopAppBar` as shipped. Compose-idiomatic.

---

## 4. Visual language (tokens)

### Color
| Token | Hex | Usage |
|---|---|---|
| `brand/green-600` | `#0B6E4F` | Primary actions, brand mark, active nav item |
| `brand/green-700` | `#075A40` | Pressed state |
| `brand/green-50` | `#E6F2ED` | Subtle success bg, selected-row bg |
| `neutral/900` | `#111418` | Primary text |
| `neutral/700` | `#3F4650` | Secondary text |
| `neutral/500` | `#6B7280` | Tertiary text, icon inactive |
| `neutral/200` | `#E6E8EC` | Divider, card border |
| `neutral/50`  | `#F7F8FA` | Screen bg |
| `surface`     | `#FFFFFF` | Card bg |
| `status/success` | `#1E8A5F` | Paid, verified, delivered |
| `status/warning` | `#D98B18` | Pending, in-transit, bid placed |
| `status/danger`  | `#C8372D` | Failed, rejected, overdue |
| `status/info`    | `#1F6FEB` | New, informational |

Dark mode: invert neutrals; keep brand-green at `#2FB989` for AA contrast on dark.

### Typography
- **Family:** Inter (system fallback: Roboto).
- **Scale (sp):** Display 32 / H1 24 / H2 20 / Title 16 semibold / Body 14 / Caption 12 / Overline 11 upper.
- Line heights: Body 20, Title 22, H1 32.

### Spacing
4 / 8 / 12 / 16 / 24 / 32 / 48. Default card padding: 16. Section gap: 24.

### Radius
8 (inputs, chips), 12 (cards), 16 (sheets), 999 (FAB, avatars).

### Elevation
0 default; 1 for cards over list bg; 2 for sticky headers; 3 for sheets; 4 for dialogs.

### Iconography
Material Symbols Outlined, 24dp stroke 2. No decorative icons in primary flows.

---

## 5. Navigation map

### 5.1 Top-level graphs
```
RootNav
├── AuthGraph (unauthenticated)
│   ├── Welcome
│   ├── SignIn
│   ├── SignUp
│   ├── OtpRequest
│   ├── OtpVerify
│   └── ForgotPassword
├── RoleSelect (first-run after sign-up)
└── MainGraph (authenticated)
    ├── Home (tab)
    ├── Marketplace (tab)
    ├── Orders (tab)
    ├── Repair (tab)
    └── Profile (tab)
```

### 5.2 Bottom nav (5 tabs — same set for all roles, content differs)
| Tab | Icon | Engineer sees | Hospital sees |
|---|---|---|---|
| Home | `home` | Job feed | Dashboard (shortcuts + recent activity) |
| Marketplace | `shopping_bag` | Browse parts (optional) | Browse parts (primary) |
| Orders | `receipt_long` | (empty state: "Parts you buy appear here") | Order history + tracking |
| Repair | `build` | Active jobs | Repair requests |
| Profile | `person` | Profile + earnings + KYC | Profile + hospital settings |

> Design note: role-aware content inside the same tab skeleton keeps the IA uniform and reduces cognitive cost when switching modes.

### 5.3 Full-screen routes (hide bottom nav)
Cart, Checkout, Order detail, Repair job detail, Conversation list, Chat thread, KYC, About, My Bids, Earnings, Active Work, Request Service.

---

## 6. Screen inventory

Every screen below needs a design. Format:
- **Purpose** · **Primary action** · **Key states** · **Data shown**

### 6.1 Auth (shared)
1. **Welcome** — Logo, 1-line tagline, "Sign in", "Create account". Bg illustration optional.
   *States:* default.
2. **Sign in** — Email + password, "Sign in", "Forgot password?", "Sign in with Google", "Sign in with OTP".
   *States:* default, loading, error (wrong creds), offline.
3. **Sign up** — Email + password + confirm password. TOS checkbox. "Create account".
   *States:* default, loading, email-taken error, weak-password error.
4. **OTP request** — Email field → "Send code".
   *States:* default, sending, sent (snackbar), rate-limited error.
5. **OTP verify** — 6-digit code input (auto-advance boxes), resend link (30s cooldown), email shown above.
   *States:* default, verifying, code-wrong, expired, resend-cooldown.
6. **Forgot password** — Email → "Send reset link". Success state.
7. **Role select** (first-run) — Big tile cards: "I'm a Hospital", "I'm an Engineer", "I'm a Supplier" (grey + "Coming soon"), "I'm a Manufacturer" (grey). CTA pinned to bottom.

### 6.2 Home
8. **Engineer Home** — Top: greeting + verification badge (green tick / amber "Complete KYC"). Big card: "Available jobs nearby" count + CTA. Row of quick tiles: *Active work*, *My bids*, *Earnings*. Secondary: "Tip of the day" collapsible.
   *States:* verified, unverified (CTA banner to KYC), no-jobs (empty), offline (cached).
9. **Hospital Home** — Greeting. Primary card: "Raise a repair request" (big). Row of tiles: *Active requests*, *Recent orders*, *Reorder*. Secondary: "Staff activity" preview.
   *States:* default, no-activity empty, offline.

### 6.3 Marketplace (buyer flow)
10. **Marketplace home** — Search bar (sticky top), category chips (scrollable), "Featured parts" horizontal carousel, "Recently viewed" carousel, "Shop by manufacturer" grid.
    *States:* default, search-focus, no-network.
11. **Search results** — Results list (card rows: thumb + title + manufacturer + ₹ + stock badge), filter chip-row (price, brand, availability), sort sheet.
    *States:* results, loading (skeletons), empty ("No parts match").
12. **Part detail** — Hero image carousel, title, manufacturer, model compatibility list, price + GST note, qty stepper, "Add to cart" (primary), "Buy now" (secondary). Specs accordion. "Related parts" strip.
    *States:* in-stock, low-stock (badge), out-of-stock (CTA disabled + "Notify me"), loading.
13. **Cart** — Line items (image, name, qty stepper, remove), subtotal / GST / delivery breakdown, coupon field, "Proceed to checkout" sticky bottom.
    *States:* populated, empty ("Your cart is empty" + browse CTA), price-changed banner.
14. **Checkout** — Address picker (select / add new), delivery slot, payment method row (Razorpay — UPI / Card / NetBanking), final totals, "Pay ₹xxx" CTA.
    *States:* default, address-missing, payment-in-progress (sheet), payment-failed, payment-success → redirect to order detail.
15. **Address form** (sheet or full) — Name, phone, line1, line2, city, state (dropdown), pincode, landmark, tag (Home/Work/Other).

### 6.4 Orders (buyer)
16. **Orders list** — Tabs: *All / Active / Delivered / Cancelled*. Each row: order id, 1–2 line item summary, status chip, ₹. Pull-to-refresh.
    *States:* populated, empty, offline (cached list with banner).
17. **Order detail** — Stepper (Paid → Packed → Shipped → Out for delivery → Delivered), line items, invoice download, delivery address, contact seller CTA, reorder CTA.
    *States:* each stepper step; cancelled; refund-in-progress; delivered.

### 6.5 Repair
18. **Request service** (hospital) — Wizard, 4 steps:
    *(1) Equipment:* type (dropdown), brand, model, serial (optional).
    *(2) Issue:* description (multiline), severity (Low / Medium / Critical).
    *(3) Photos:* up to 5, camera or gallery.
    *(4) Schedule + location:* preferred slot, site address (auto from hospital profile with override).
    Progress bar at top. "Back" / "Next" bottom. Final review → "Submit".
    *States:* per step valid / invalid; submitting; submitted success (→ detail).
19. **Repair list** — Hospital view: *My requests* tabs (Open / Bids received / In progress / Completed). Engineer view: *Available jobs* + *My jobs*.
    *States:* populated, empty, filter applied.
20. **Repair job detail** — Header (equipment + hospital + severity chip), issue description, photos, map thumb with address, bid section (hospital: list of bids with accept/reject; engineer: "Place bid" CTA or "Your bid" card), "Message requester" secondary, status stepper at bottom.
    *States:* open / bid-placed / accepted / en-route / on-site / completed / cancelled.
21. **Place bid sheet** — ₹ amount, ETA (hours), note, "Submit bid".
    *States:* default, submitting, success, already-bid (edit mode).
22. **Engineer job feed** (Home CTA target) — List of available jobs sorted by distance. Card: equipment + hospital + distance + severity + ₹-range (if visible). Filter: radius, severity, equipment type.
    *States:* populated, empty ("No jobs in 10 km"), offline.

### 6.6 Chat
23. **Conversations list** — Rows: counterparty avatar + name, last message preview, timestamp, unread dot.
    *States:* populated, empty, offline.
24. **Chat thread** — Bubble list (sent right, received left), input bar with send + attach (photo). Typing indicator. Day dividers.
    *States:* connected, reconnecting banner, send-failed (retry tap), attachment uploading.

### 6.7 Profile
25. **Profile home** — Header: avatar, name, role chip, verification badge. Sections: *Personal info*, *Addresses* (hospital), *Bank details* (engineer), *Verification / KYC* (engineer), *Notifications*, *Language*, *About*, *Sign out*.
    *States:* role-specific sections visible/hidden.
26. **Edit profile** — Form: name, phone (display only since no phone OTP), secondary email, avatar upload. "Save".
27. **KYC / Verification (engineer)** — Status banner (Pending / In review / Approved / Rejected + reason). Upload slots: *Aadhaar*, *PAN*, *Trade certificate*, *Profile photo*. Each slot: thumbnail + replace CTA. Submit enables when all mandatory uploaded.
    *States:* not-started, partial, submitted (locked), approved, rejected-with-reason.
28. **Earnings (engineer)** — Summary card: this month ₹ + paid ₹ + pending ₹. List of transactions (job title, date, ₹, status chip). Request payout CTA if pending ≥ ₹500.
    *States:* populated, empty, payout-in-progress.
29. **Active work (engineer)** — List of accepted jobs with quick action chips: *Check in*, *Mark done*, *Upload photo*.
30. **My bids (engineer)** — Tabs: *Pending / Accepted / Rejected*. Each row: job + ₹ + status.
31. **Notifications settings** — Toggle list: *Orders*, *Jobs*, *Chat*, *Account*. Each toggles push + email independently.
32. **About** — App version, licenses, ToS, Privacy, contact support, website link.

### 6.8 System / utility
33. **Global empty states** — illustration + 1-line message + CTA. Reusable.
34. **Global error screens** — "Something went wrong" with retry. Offline banner pattern.
35. **Permissions rationale screens** — Camera (for photos), Location (for nearby jobs), Notifications (for job + chat). Pre-prompt before OS dialog.
36. **Deep-link return sheet** — Razorpay post-payment confirmation (success / failed / pending).

---

## 7. Component inventory (design system)

Primitives:
- `AppButton` (primary / secondary / tertiary / destructive)
- `AppTextField` (label, helper, error, leading/trailing icon)
- `AppOtpInput` (6-digit auto-advance)
- `AppChip` (filter / status / selectable)
- `AppCard` (rest / elevated / outlined)
- `AppListRow` (leading visual + title + subtitle + trailing)
- `AppTopAppBar` (title, nav icon, action icons, scroll behavior)
- `AppBottomNav` (5 items, badge support)
- `AppBadge` (count / dot)
- `AppAvatar` (initials fallback)
- `AppDialog` (title, body, 2 actions)
- `AppBottomSheet` (modal / partial)
- `AppSnackbar` (info / success / warning / error)
- `AppProgress` (linear + skeleton)
- `AppStepper` (horizontal for wizards, vertical for status timeline)
- `AppEmptyState`
- `AppErrorState`
- `AppQtyStepper`
- `AppStatusChip` (Paid / Shipped / In progress / etc — colors from §4)
- `AppPhotoGrid` (uploader + viewer)
- `AppMapThumb` (static map preview)

---

## 8. Critical flows (end-to-end, for prototyping)

1. **Engineer onboarding:** Welcome → Sign up → OTP verify → Role select (Engineer) → Home (unverified banner) → KYC → Submit → "In review" state.
2. **Engineer earns first job:** Home → Engineer job feed → Job card tap → Job detail → Place bid → Bid confirmed → Chat thread opens → Bid accepted push → Check in → Photos + done → Earnings updated.
3. **Hospital buys a part:** Home → Marketplace → Search "ECG electrode" → Part detail → Add to cart → Cart → Checkout → Razorpay sheet → Success → Order detail (stepper: Paid).
4. **Hospital raises a repair:** Home → "Raise a repair" → 4-step wizard → Submit → Repair detail (status: Open, awaiting bids).
5. **Hospital picks an engineer:** Repair detail → Bids section → Accept → Chat opens → Engineer arrives → Mark done → Rate.
6. **Password reset:** Welcome → Sign in → Forgot password → Email sent → (deep-link back) → New password → Sign in.

---

## 9. Accessibility

- Every interactive node has a `contentDescription` / `semantics {}`.
- Minimum touch target 48dp (primary 56dp).
- Text scales with system dynamic type up to 130% without clipping.
- Color-not-the-only-signal for status chips (icon + label always).
- Focus order top-left → bottom-right; no trap in dialogs.
- Contrast ≥ 4.5:1 body, 3:1 large.

---

## 10. Platform specifics

- **Material 3**, single top-level theme with light + dark.
- **Min SDK 26 (Android 8)**, target SDK 35 (Android 15).
- **Compose-only** — no XML views in new screens.
- **Edge-to-edge** with proper insets handling on both top and bottom (gesture nav vs 3-button nav).
- **Navigation:** Jetpack Navigation-Compose. `singleTop` launch mode on `MainActivity`.
- **Fonts:** Inter via `androidx.compose.ui.text` font resources; system fallback Roboto.
- **Animations:** Prefer built-in Compose transitions; `AnimatedVisibility` + `AnimatedContent`. Keep under 250ms.
- **Haptics:** light tick on primary CTA success; nothing on scroll.
- **Push channels:** `orders`, `jobs`, `chat` (with reply action), `account`.
- **Deep links:** `equipseva://` scheme — routes: `/orders/{id}`, `/repair/{id}`, `/chat/{id}`, `/payment/return`.

---

## 11. States every screen must design

For each screen in §6, the designer must show:
1. **Loading** (skeleton, not spinner where list-shaped).
2. **Empty** (illustration + message + CTA).
3. **Error** (retry + reason if known).
4. **Offline** (top banner + cached content if available).
5. **Success** (happy path).

---

## 12. Non-goals (do NOT design)

- Tablet / foldable specific layouts.
- Watch companion.
- In-app video calls (link out to WhatsApp).
- AI chat inside Android v1 (support chat lives on web).
- Supplier / Manufacturer / Admin / Logistics Android experiences.
- Phone OTP (email OTP only).
- Hindi localization (post-launch).

---

## 13. Deliverables for the designer

Hand back:
1. **Figma file** (or equivalent) with:
   - Design tokens as styles/variables.
   - Component library matching §7.
   - All 36 screens in §6 with the 5 states from §11.
   - The 6 critical flows in §8 as clickable prototypes.
2. **Export** for dev:
   - Color + type styles as a JSON token file.
   - Icons as 24dp SVGs (outlined).
   - Spacing scale reference.
3. **Redlines** for §8 flows (screen-to-screen transitions, modal vs push, bottom sheet vs full-screen decisions).

---

## 14. Out-of-band constraints (do not override)

- Brand green `#0B6E4F` is locked (cross-surface with web + iOS).
- Bottom nav is 5 tabs, not 4, not 6.
- English only at launch.
- No phone OTP anywhere.
- No tablet layouts v1.
- Razorpay is the only payment UI surface; we render Razorpay's native sheet, not our own.

---

## 15. Open questions for the designer

1. Should engineer Home default to *job feed* (dense, utilitarian) or *dashboard* (summary)? Recommendation: dashboard with job count front-and-center; feed is 1 tap away.
2. KYC rejection — in-app reason + re-upload, or deep-link to web? Recommendation: in-app; engineers are mobile-primary.
3. Ratings — show engineer rating to hospitals in job feed? (Not locked yet; design both variants.)
4. Dark mode parity on day 1 or post-launch? Recommendation: day 1 at token level; polish post-launch.

---

*End of PRD.*
