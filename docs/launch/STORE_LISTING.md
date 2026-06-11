# Play Store Listing — EquipSeva

Copy each block into the matching field in Play Console → Main store listing.

---

## App title (≤30 characters)

```
EquipSeva: Hospital Equipment
```

(28 characters, includes the space)

**Alternates if the above is taken:**
- `EquipSeva — Med Equipment` (25)
- `EquipSeva: Repairs & Parts` (26)

---

## Short description (≤80 characters)

```
Book verified biomedical engineers for hospital equipment repair & maintenance.
```

(79 characters)

**Alternates:**
- `India's marketplace for hospital biomedical engineers — repair & AMC plans.` (74)
- `Find biomedical engineers. Book repairs. Set up monthly maintenance.` (68)

> Note (round 478): spare-parts marketplace copy removed — feature is on the v0.4 roadmap (DB schema exists, UI not yet shipped). Don't promise what doesn't ship.

---

## Full description (≤4000 characters)

```
EquipSeva is India's marketplace for hospital equipment repair — connecting you to verified biomedical engineers in one app.

Whether you run a 30-bed nursing home or a multi-specialty hospital, downtime on a critical machine costs money and risks patients. EquipSeva connects you to verified biomedical engineers so a broken ventilator, ECG, ultrasound, or anaesthesia workstation gets back into service in days, not weeks.

WHAT YOU CAN DO

For Hospitals
• Book a verified biomedical engineer for on-site repair or diagnostics. Compare bids by price, ETA, and rating.
• Set up monthly maintenance (AMC) contracts with engineers you trust — predictable preventive care without paperwork.
• Track every repair with real-time status: Posted → Bids → Accepted → In progress → Completed.
• Pay securely with cards, UPI, net-banking, or wallets via Razorpay. Money is held in escrow on every repair job and only released when you confirm completion.
• Chat directly with engineers in-app — share equipment photos, confirm specs, get ETA updates without WhatsApp.

For Engineers
• Discover repair jobs near you and bid with your price + ETA.
• Complete KYC once and get a verified badge that hospitals trust.
• Take on monthly maintenance contracts for predictable income.
• Get paid through escrow, with payouts released the moment the hospital confirms completion or 48 hours after job close.
• Build a reputation through ratings and reviews.

WHY EQUIPSEVA

• Verified engineers. Every engineer completes KYC with government photo ID and a live selfie before hospitals see them.
• Escrow-protected payments. Hospitals don't pay until the job is done.
• Real-time chat. Negotiate, share photos, confirm specs without WhatsApp.
• Push notifications you control. Mute by category, set quiet hours, and only get pinged for what matters.
• Built for India. Razorpay payments, GST-aware invoicing, RBI-compliant refunds, DPDP-compliant data handling.

COMING SOON
• Spare-parts marketplace and supplier flows are on our roadmap and will arrive in a future update.

PRIVACY AND SAFETY

• Bank-grade TLS encryption with certificate pinning.
• Local data on your phone is encrypted with SQLCipher.
• You can delete your account or export all your data from inside the app — DPDP Act compliant.
• In-app report and block tools keep conversations safe.

WHO WE'RE FOR

Hospitals, nursing homes, diagnostic labs, and biomedical engineers across India. Sign-up is free; you only pay when you book a repair.

QUESTIONS

Email support@equipseva.com or use Profile → Help in the app. We respond within one business day.

EquipSeva — keep equipment running, keep care moving.
```

(2,765 / 4,000 characters)

---

## Category

- **Primary category:** Medical
- **Tags:** Healthcare, B2B, Marketplace

---

## Contact details

- **Website:** https://equipseva.com
- **Email:** support@equipseva.com
- **Phone (optional):** _[leave blank unless you want to publish one — Play allows it to be hidden]_
- **Privacy Policy URL:** https://equipseva.com/privacy/

---

## Translations

English (en-IN) only at launch. Add Hindi (hi-IN) and Telugu (te-IN) post-launch.

---

## App access

- The full app is unlocked behind a sign-up and (for engineers/suppliers) KYC. For Play review, provide these test accounts through Play Console → App content → App access:

  **Hospital reviewer account (primary):**
  - Username: `play-review-hospital@equipseva.com`
  - Password: `PlayReview2026!`
  - Notes: "Hospital role; full marketplace, repair-job posting, AMC contracts, and chat are accessible. Engineer flows require KYC — use the engineer account below."

  **Engineer reviewer account (KYC fast-path-approved):**
  - Username: `play-review-engineer@equipseva.com`
  - Password: `PlayReview2026!`
  - Notes: "Engineer role with verification_status='verified' (KYC pre-approved for review). Can accept repair-job bids, manage earnings, and complete maintenance visits."

  Both accounts are seeded in Supabase Auth. The engineer's `verification_status` is force-set to 'verified' so reviewers can exercise engineer flows without uploading real KYC docs.

---

## Screenshots (need design output)

Required: at least 8 phone screenshots, 16:9 or 9:16 aspect, 1080×1920 or 1920×1080, ≤8 MB each.

Suggested set, in order:
1. **Home** — hospital role, hero with "Book a repair", "Find spare parts", "Post RFQ".
2. **Marketplace listing** — grid of spare parts with photos, prices, ratings.
3. **Part detail** — specs, OEM badge, "Add to cart" + chat-with-supplier.
4. **Cart + Checkout** — item list, GST, shipping address, Razorpay button.
5. **Order detail** — status timeline (Placed → Confirmed → Shipped → Delivered).
6. **Repair job creation** — equipment picker, problem description, photo upload.
7. **Bids inbox** — list of engineer bids with price, ETA, rating.
8. **Chat thread** — typing indicator, photo share, "Order shipped" system message.
9. **KYC** (engineer) — ID upload + selfie capture screens.
10. **Notifications inbox + per-category mute settings.**

Feature graphic (1024×500 PNG, ≤1 MB): hero shot of the marketplace tile + tagline.

---

## App icon

512×512 PNG master + adaptive XML are already in the repo. **Confirm with brand owner that the current vector is the final mark before submitting.** If not, replace `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` and the corresponding `mipmap-*` PNGs.
