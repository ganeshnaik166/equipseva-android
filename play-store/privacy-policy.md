# EquipSeva Privacy Policy

**Effective date: 2026-04-27**
**Last updated: 2026-04-27**

EquipSeva ("EquipSeva", "we", "us", "our") operates the EquipSeva Android
application and the website at https://equipseva.com ("Service"). This policy
explains what personal information we collect, why we collect it, who we share
it with, how long we keep it, and the rights you have under India's Digital
Personal Data Protection Act, 2023 (DPDP Act) and the EU General Data
Protection Regulation (GDPR).

If you have questions, contact us at **support@equipseva.com**.

---

## 1. Who we are

EquipSeva is a marketplace that connects hospitals, clinics, and diagnostic
centres in India with verified biomedical engineers for medical-equipment
repair. We are the **data fiduciary** (DPDP Act) and **data controller** (GDPR)
for the personal data described in this policy.

Postal address: EquipSeva, Nalagonda, Telangana, India.

## 2. Personal data we collect

| Data | Why we collect it | When we collect it |
|------|-------------------|--------------------|
| Full name | Identify you to engineers / hospitals on the other side of a job | Sign-up |
| Phone number | Account login (OTP), in-app calling, WhatsApp deep links | Sign-up |
| Email address | Transactional email, account recovery, support replies | Sign-up |
| Aadhaar number (last 4 digits hashed for display only) | KYC verification — required by Indian medical-procurement norms before an engineer can bid | KYC step |
| KYC document images (Aadhaar front/back, PAN, certifications) | Verify the engineer is who they claim to be; verify the hospital procurement contact is authorised | KYC step |
| Profile photo | Lets the other side recognise you on arrival | Profile setup |
| Live selfie | Liveness check during KYC to deter fake engineer profiles | KYC step |
| Approximate location (city / pincode) | Match engineers to hospitals within a 50 km service radius | Sign-up + ongoing |
| Precise device location | Optional — only when you tap "Use my current location" to autofill an address | On demand |
| Equipment photos and fault descriptions | Help engineers diagnose before arrival | When you post a job |
| Before/after job completion photos | Proof-of-work for the hospital and the engineer's portfolio | Job completion |
| In-app chat messages | Communication between hospital and engineer about a specific job | While the job is open |
| Device identifiers (Android ID, install ID) | Anti-fraud, install attribution | App install |
| FCM push token | Send push notifications about job status, bids, chat messages | App install |
| Crash reports + non-personal device telemetry (OS version, model, RAM, free storage) | Diagnose crashes via Sentry / Firebase Crashlytics | On crash |
| Play Integrity verdict | Detect rooted / tampered devices to protect KYC data | Each session |

We do NOT collect:
- Payment card / UPI credentials. (Razorpay handles payments in v2 directly;
  we never see card numbers.)
- Health records of patients. EquipSeva is a B2B repair tool, not a clinical
  system.
- Microphone audio or video calls. Calls happen via your phone's native
  dialler / WhatsApp.

## 3. Why we process your data (lawful basis)

- **Performance of contract** — to operate the marketplace, match jobs,
  enable chat, and bill (DPDP Act §7(a), GDPR Art 6(1)(b)).
- **Legal obligation** — to retain KYC records for the period required under
  Indian KYC and tax law (DPDP Act §7(c), GDPR Art 6(1)(c)).
- **Legitimate interest** — to detect fraud, secure the platform, and improve
  the product (GDPR Art 6(1)(f)). We have run a balancing test; you can object
  any time at support@equipseva.com.
- **Consent** — for optional precise location, push notifications, and
  marketing communications (DPDP Act §6, GDPR Art 6(1)(a)). You can withdraw
  consent at any time inside the app or by emailing us.

## 4. Third parties we share data with

| Third party | What we share | Why | Where data lives |
|-------------|---------------|-----|------------------|
| Supabase (Postgres, Storage, Realtime, Edge Functions) | All app data | Primary backend / database | AWS Mumbai region (`ap-south-1`) |
| Google Play Services for Maps | Approximate / precise location, map tile requests | Render service-area maps and address autocomplete | Google global infra |
| Google Firebase Cloud Messaging | FCM token, notification payloads | Deliver push notifications | Google global infra |
| Google Firebase Crashlytics | Crash stack traces, OS / device model | Diagnose crashes | Google global infra |
| Google Play Integrity API | Device integrity verdict | Anti-fraud | Google global infra |
| Sentry | Crash + performance traces (PII scrubbed) | Diagnose crashes / slow flows | Sentry US/EU |
| Razorpay (v2 only) | Order amount, contact name, phone, email | Process payments when v2 marketplace launches | Razorpay India |
| ImprovMX | Inbound email from `*@equipseva.com` | Email forwarding | ImprovMX US |

We do not sell personal data. We do not share data for advertising. We have
data-processing agreements (DPAs) with each provider.

## 5. International transfers

Some processors (Google, Sentry) store data outside India. We rely on the
European Commission's Standard Contractual Clauses and equivalent India-OECD
safeguards. The DPDP Act permits cross-border transfer to countries not on the
Indian Government's restricted list.

## 6. How long we keep your data

| Data | Retention |
|------|-----------|
| Account profile | Until you delete your account, then 30 days in soft-delete then purged |
| KYC documents | 7 years after account closure (Indian KYC + tax retention) |
| Job records | 7 years (commercial / GST records) |
| Chat messages | 2 years from last message, then archived for legal hold only |
| Crash logs | 90 days |
| FCM token | Until app uninstall or token rotation |

## 7. Your rights

Under both DPDP Act and GDPR you have the right to:

- **Access** — request a copy of your personal data.
- **Correct** — fix inaccurate data (most fields are editable in-app).
- **Erase / Delete account** — use **Settings > Account > Delete Account**
  inside the app, or email support@equipseva.com. Deletion runs within 30 days
  except for KYC + job records held for legal retention.
- **Portability** — request a machine-readable export.
- **Withdraw consent** — for optional location / push / marketing.
- **Lodge a complaint** — with the Data Protection Board of India
  (under DPDP Act) or your local EU Data Protection Authority (under GDPR).
- **Nominate** (DPDP Act §14) — appoint another individual to exercise rights
  on your behalf if you become incapacitated.

To exercise any right, email **support@equipseva.com** with the subject "DPDP
Request" or "GDPR Request". We will respond within 30 days.

## 8. Security

- All traffic is TLS 1.2+.
- KYC documents are encrypted at rest in Supabase Storage with per-object keys.
- The local Room database is encrypted with SQLCipher; the passphrase lives in
  the Android Keystore and never leaves the device.
- Push tokens, role flags, and onboarding state live in
  EncryptedSharedPreferences.
- Row-Level Security (RLS) policies are enforced on every Supabase table —
  users can only read / write their own data.
- We run continuous static + manual security review on every release.

## 9. Children

EquipSeva is a B2B service for hospitals and certified biomedical engineers.
It is not directed to anyone under 18. We do not knowingly collect data from
minors. If you believe a minor has signed up, email us and we will delete the
account.

## 10. Changes to this policy

We will post the new policy at https://equipseva.com/privacy and bump the
"Last updated" date. Material changes will trigger an in-app notice and, where
required by law, a fresh consent prompt.

## 11. Contact

EquipSeva
support@equipseva.com
Nalagonda, Telangana, India

For DPDP Act §10 we are the **Data Fiduciary**. The Data Protection Officer
can be reached at the same address.
