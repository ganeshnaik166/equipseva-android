# Play Store Listing — EquipSeva

Paste-ready copy for Play Console → Store presence → Main store listing.
All copy is under Google's character limits (App name 30, Short description 80, Full description 4000).

---

## App name (30 chars max)

```
EquipSeva
```

## Short description (80 chars max)

```
Find verified biomedical engineers near you. Book repair jobs, manage AMC contracts.
```

## Full description (4000 chars max)

```
EquipSeva is India's marketplace for biomedical equipment service. Hospitals find verified, rated engineers near them. Engineers grow a trusted business without paying for leads.

WHO IT'S FOR
• Hospitals, clinics, and diagnostic centres that own medical equipment
• Independent biomedical engineers and service companies
• Equipment suppliers and manufacturers running service operations

WHAT YOU CAN DO

For hospitals:
• Post a repair job and receive competing bids from verified engineers in your district
• See ratings, prior job count, brand specializations, and indicative hourly rates upfront
• Pay through EquipSeva Escrow — the engineer is paid only after the job is complete
• Set up monthly Annual Maintenance Contracts (AMC) with engineers you trust
• Track contract balance, scheduled visits, SLA compliance, and dispute resolution in one place
• Chat with the engineer through the app — your real phone number stays private

For engineers:
• Browse open repair jobs filtered by your district and specialization
• Place bids, accept jobs, and run them end-to-end without paper invoices
• Build a rated public profile that hospitals see — verified KYC, OEM training badges, completion rate
• Receive payouts directly to your bank account; AMC contracts pay monthly into a pool
• Get paged for emergency response visits with clear response-time SLAs

TRUST + SAFETY
• KYC verification for every engineer — Aadhaar, PAN, bank account
• Razorpay-powered payments with HMAC signature verification and escrow holdback
• Identity-masked contact: chat and call routing keep phone numbers private until both sides agree
• Photo evidence required at every job stage (before / during / after)
• Disputes resolved by a human review team within 48 hours
• PII redacted from logs, chat, and crash reports

PRIVACY + COMPLIANCE
• DPDP-compliant account deletion: every PII column is purged on request
• HTTPS-only network with certificate pinning to supabase.co and razorpay.com
• No third-party advertising trackers
• Tamper-evident builds with Play Integrity verification

EARLY ACCESS
EquipSeva is currently in private beta in Telangana. Sign up to be notified when we open in your state.

Questions or feedback? Email support@equipseva.com or visit equipseva.com.
```

## What's new (500 chars max per release)

```
First public release.

• Hospital booking flow with verified engineer directory
• Engineer profile with ratings, KYC, specializations
• Razorpay Escrow with 48h auto-release after completion
• AMC contracts with monthly visits, SLA tracking, pool balance
• Identity-masked chat + call routing
• DPDP-compliant account deletion
• Pin-protected HTTPS to Supabase + Razorpay
• PII-redacted observability
```

---

## App category

- **Primary:** Business
- **Tags:** Medical, Tools

## Contact details

- **Email:** support@equipseva.com  (forward to ganesh1431.dhanavath@gmail.com via ImprovMX)
- **Website:** https://equipseva.com
- **Privacy policy:** https://equipseva.com/privacy

## Content rating questionnaire — likely answers

- Violence: None
- Sex / nudity: None
- Profanity: None
- Drug / alcohol references: None
- Gambling: None
- User-generated content: Yes (chat between hospital and engineer — moderated with PII redaction + report flow)
- Location sharing: Yes (hospital pin during booking, engineer service area)
- Personal info collection: Yes (phone, email, Aadhaar/PAN for engineer KYC) — handled per DPDP

Expected rating: **Everyone**.

## Data safety questionnaire — pre-filled answers

| Data type | Collected? | Shared? | Purpose | Required? |
|---|---|---|---|---|
| Email | Yes | No | App functionality, Account management | Required |
| Phone number | Yes | No | App functionality (escrow + chat), Account management | Required |
| Name | Yes | No | App functionality, Account management | Required |
| User ID (auth.uid) | Yes | No | App functionality | Required |
| Address | Yes (hospital pin, engineer service area) | No | App functionality (matching) | Optional |
| Precise location | Yes (one-time on booking) | No | App functionality (nearest engineer) | Optional |
| Photos | Yes (job evidence, KYC docs) | No | App functionality | Required for engineers |
| Bank account info | Yes (engineer payout) | Shared with Razorpay | Payments | Required for engineers |
| Government ID | Yes (Aadhaar / PAN for engineer KYC) | Shared with Razorpay for KYC | Account management | Required for engineers |
| Financial info — purchase history | Yes (job costs, AMC dues) | No | App functionality | Required |
| App activity — app interactions | Yes | No | Analytics, Crash reports | Optional |
| Device or other IDs | Yes (FCM token, Play Integrity) | No | Account management, Security | Required |

Data encrypted in transit: **Yes** (HTTPS-only + cert pinning).
Data deletion option: **Yes** (Profile → Delete account, executes server-side wipe within 24h).

## Screenshots checklist (still needed from user)

- [ ] 1080×1920 minimum, 16:9 or taller
- [ ] At least 2 phone screenshots, ideally 4–8
- [ ] Cover hospital home, engineer directory, booking wizard, AMC tab, chat
- [ ] No status bar PII (use the debug variant signed in to a sanitized account)

## Feature graphic (required, 1024×500)

- [ ] Design — green/white EquipSeva brand bar with wrench + heart-cross icon
- [ ] Tagline: "Verified biomedical service, on tap"

## App icon (already shipped — adaptive icon at mipmap-anydpi-v26)

✓ in repo
