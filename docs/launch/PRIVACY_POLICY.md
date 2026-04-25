---
title: Privacy Policy
permalink: /privacy/
redirect_from:
  - /privacy-policy/
  - /launch/PRIVACY_POLICY/
  - /launch/PRIVACY_POLICY.html
---

# Privacy Policy — EquipSeva

**Effective:** 2026-04-25
**Last updated:** 2026-04-25

EquipSeva ("we", "us", "our") operates the EquipSeva mobile application ("App"), a marketplace connecting hospitals, biomedical engineers, suppliers, manufacturers, and logistics partners for hospital equipment, spare parts, and repair services in India. This policy explains what we collect, why, with whom we share it, and the rights you have under the Digital Personal Data Protection Act, 2023 ("DPDP Act").

By creating an account, you consent to the collection and processing described here.

---

## 1. Who is the data fiduciary

EquipSeva is the data fiduciary under the DPDP Act for the personal data we process through the App.

**Grievance Officer:**
- Name: _[FILL IN — required by DPDP §10(8)]_
- Email: grievance@equipseva.com _[update once domain is live]_
- Address: _[FILL IN registered office address]_

We will respond to grievances within 30 days as required by DPDP §13.

---

## 2. What we collect

### From you, when you create an account
- Email address (sign-in identifier)
- Mobile phone number (notifications + customer support)
- Full name
- Password (stored as a salted hash via Supabase Auth — we never see the plaintext)
- Role you pick (hospital, engineer, supplier, manufacturer, logistics)
- Organisation name (if applicable)

### From you, during KYC verification (engineers + suppliers)
- Government photo ID number (Aadhaar / PAN / driving licence — your choice)
- Photograph of your ID document
- Selfie photo for liveness check
- Professional certifications you upload

### From you, in normal use
- Shipping addresses (when placing spare-part orders)
- Chat messages with other users
- Listings, RFQs, bids, repair requests you create
- Photos you upload (repair photos, listing photos, equipment scan photos)
- Order, payment, and review history

### Automatically, from your device
- Firebase Cloud Messaging (FCM) push token — to send you notifications
- App version, OS version, device model — for crash diagnostics
- Coarse usage events (e.g. "checkout started") — anonymised analytics
- Crash reports and stack traces — captured by Sentry and Firebase Crashlytics

### From payment partners
- Razorpay shares back the success/failure status, the Razorpay payment ID, and the order amount. **We do not see, store, or process your card number, CVV, UPI PIN, or net-banking credentials** — those go directly from your device to Razorpay.

### What we explicitly do NOT collect
- Precise GPS location (we ask you to type a shipping address; we do not run a background location service)
- Contacts list / phonebook
- Photos other than the ones you choose to upload
- SMS / call logs
- Microphone audio
- Health data
- Children's data — the App is intended for users 18 and older; if we discover an under-18 account we will delete it on confirmation.

---

## 3. Why we process this data — purposes and lawful basis

| Purpose | Data used | Lawful basis (DPDP §7) |
|---|---|---|
| Create + maintain your account | Email, phone, name, password hash | Consent (sign-up) |
| Verify engineer / supplier identity | KYC documents + selfie | Consent + legitimate interest (fraud prevention) |
| Show listings, run RFQs, route repair jobs | Listings, RFQs, bids, role | Performance of contract |
| Process payments | Order amount, payment ID returned by Razorpay | Performance of contract |
| Send push notifications you opted into | FCM token, mute preferences | Consent |
| Customer support and dispute resolution | Order, chat, payment history | Legitimate interest |
| Detect fraud, abuse, tampering | Device integrity signals, signed-cert hash, Play Integrity verdicts | Legitimate interest (DPDP §7(j)) |
| Crash diagnostics and quality | Anonymised crash reports, stack traces, app-version metadata | Legitimate interest |
| Comply with legal obligations | Whatever the law requires | Legal obligation (DPDP §7(c)) |

We do not sell your data. We do not use it for advertising or profiling.

---

## 4. Who we share it with — third-party processors

We use these processors. Each is bound by a data-processing agreement:

| Processor | What they receive | Where |
|---|---|---|
| **Supabase** (Postgres DB, Auth, Storage, Realtime, Edge Functions) | All app data + KYC document blobs | AWS Mumbai region (ap-south-1) |
| **Razorpay** | Payment transactions only | India |
| **Firebase Cloud Messaging** | FCM token + push payload | Google global infrastructure |
| **Firebase Crashlytics** | Crash stack traces (no PII) | Google global infrastructure |
| **Firebase Analytics** | Anonymised events | Google global infrastructure |
| **Sentry** | Crash + error reports (PII-stripped, user_id only) | Sentry EU region |
| **Google Play Integrity** | Device-integrity verdict on your device (no PII) | Google global infrastructure |

We do not sell or rent your data to anyone. We will only disclose it to law enforcement on receipt of a valid legal order under Indian law.

---

## 5. How long we keep it

| Data | Retention |
|---|---|
| Account data (email, phone, name) | While account is active + 90 days after deletion request |
| KYC documents | 5 years from KYC completion (RBI / regulatory requirement) |
| Payment records | 8 years (Income Tax Act + RBI requirements) |
| Chat messages | 2 years from last message in the conversation |
| Listings, orders, RFQs, bids | 5 years (commercial-records requirement) |
| Crash reports | 90 days |
| FCM token | While you're signed in; cleared on sign-out |

After these periods, data is deleted or anonymised.

---

## 6. Your rights under the DPDP Act

You have these rights, exercisable from inside the App (Profile → Privacy):

- **Right to access (DPDP §11):** "Export my data" downloads a JSON archive of everything we have about you.
- **Right to correction (DPDP §12):** Edit your profile, address, etc. directly in the App.
- **Right to erasure (DPDP §12):** "Delete my account" performs an immediate logical delete; data is purged after the 90-day grace period.
- **Right to grievance redressal (DPDP §13):** Email the Grievance Officer above.
- **Right to nominate (DPDP §14):** Email us to nominate a person who can exercise these rights on your behalf in case of incapacity or death.
- **Right to withdraw consent (DPDP §6(4)):** You may withdraw consent at any time; some features (e.g. KYC-gated engineer payouts) will stop working as a result.

We aim to action all requests within 7 days; the statutory cap is 30 days.

---

## 7. How we keep it safe

- **TLS 1.2+** encrypts all traffic between the App and our servers.
- **TLS certificate pinning** prevents man-in-the-middle interception.
- **At-rest encryption:** the local database on your device uses SQLCipher with a key wrapped by the Android Keystore. Server-side databases run on encrypted-at-rest storage.
- **EncryptedSharedPreferences** protects sensitive on-device preferences.
- **Row Level Security (RLS):** every server query runs against per-user policies; one user cannot read another user's rows.
- **Signature verification + Play Integrity** detect tampered or rooted devices and refuse sensitive operations.
- **Sensitive screens (payment, KYC, profile, earnings, order detail) set FLAG_SECURE** so they cannot be screenshotted or screen-recorded.

No system is invulnerable; if you suspect a breach affecting your account, email security@equipseva.com.

---

## 8. International transfers

We process data in India (Supabase ap-south-1 region for primary storage). Some processors (Sentry, Firebase) operate globally; in those cases, transfers happen under standard contractual clauses or equivalent safeguards.

---

## 9. Cookies and similar technologies

The App does not use web cookies. It uses standard mobile-OS storage (DataStore, EncryptedSharedPreferences, SQLCipher Room database) for app state.

---

## 10. Changes to this policy

We will notify you in-App at least 7 days before a material change. Continued use of the App after the effective date constitutes acceptance.

---

## 11. Contact

- General privacy: privacy@equipseva.com
- Grievance Officer: see §1 above
- Security incidents: security@equipseva.com
- Postal: _[FILL IN registered office address]_
