# EquipSeva — Play Console Data Safety Form

For Play Console > App content > Data safety. Updated 2026-04-26.

---

## Top-level declarations

| Question | Answer |
|----------|--------|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (TLS 1.2+ everywhere) |
| Do you provide a way for users to request that their data be deleted? | **Yes** — in-app **Settings > Account > Delete Account**, plus support@equipseva.com fallback |
| Has your app been independently validated against a global security standard? | **No** (v1 — plan SOC 2 Type 1 in v2) |
| Does your app comply with the Families Policy? | **No / N/A** — app is not directed to children |

---

## Data types

For each row: **Collected** = we read it; **Shared** = we send it to a third
party we don't control; **Ephemeral** = held only in memory during the request;
**Required** = user can't proceed without providing it; **Optional** = user
can skip and still use the app.

### Personal info

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Name | Yes | Yes (engineer ↔ hospital match) | No | Required | App functionality, account management |
| Email address | Yes | No | No | Required | Account management, communications |
| Phone number | Yes | Yes (engineer ↔ hospital — for direct call / WhatsApp) | No | Required | App functionality, account management |
| Address | Yes | Yes (hospital service address shared with the engineer assigned to the job) | No | Required for hospitals | App functionality |
| User IDs (UUID) | Yes | Yes (Supabase, Sentry) | No | Required | Analytics, fraud prevention |
| Other info: Aadhaar / PAN / KYC documents | Yes | No | No | Required for engineers + procurement leads | Compliance, fraud prevention |

### Financial info

None in v1. (v2 will add Razorpay; re-answer this section then.)

### Health and fitness

None.

### Messages

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| In-app messages | Yes | No (only between the two participants of a job) | No | Optional | App functionality |
| Emails | No | — | — | — | — |
| SMS / MMS | No | — | — | — | — |

### Photos and videos

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Photos (KYC documents, profile photo, equipment photos, before/after job photos) | Yes | No (visible only inside the matched job) | No | Required for KYC; Optional for equipment photos | App functionality, fraud prevention |
| Videos | No | — | — | — | — |

### Audio files

None.

### Files and docs

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Files and docs (engineer certifications PDF) | Yes | No | No | Optional | App functionality |

### Calendar / Contacts

None.

### App activity

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| App interactions (taps, screen views) | Yes | Yes (Sentry, Firebase Analytics) | No | Required | Analytics, app functionality |
| In-app search history | Yes | No | No | Optional | App functionality |
| Installed apps | No | — | — | — | — |
| Other user-generated content (job posts, bids, ratings) | Yes | No | No | Required | App functionality |
| Other actions: bid placement, job acceptance | Yes | No | No | Required | App functionality |

### Web browsing

None.

### App info and performance

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Crash logs | Yes | Yes (Sentry, Firebase Crashlytics) | No | Required | Analytics |
| Diagnostics (OS, device model, RAM, free storage, ANR traces) | Yes | Yes (Sentry, Firebase Crashlytics) | No | Required | Analytics, app functionality |
| Other app performance data | Yes | Yes (Sentry traces) | No | Required | Analytics |

### Device or other IDs

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Device or other IDs (Android ID, install ID, FCM token) | Yes | Yes (FCM token to Google for push delivery) | No | Required | App functionality, fraud prevention |

### Location

| Data | Collected | Shared | Ephemeral | Required / Optional | Purposes |
|------|-----------|--------|-----------|---------------------|----------|
| Approximate location (city / pincode) | Yes | Yes (visible inside the matched job) | No | Required | App functionality (engineer ↔ hospital matching) |
| Precise location (GPS) | Yes | No | **Yes — used in-memory only to autofill an address; never persisted to server** | Optional | App functionality |

---

## Per-purpose declarations (Google asks per data type)

For every data type above, the purposes selected are drawn from this set:

- **App functionality** — running the marketplace, matching, chat, push.
- **Analytics** — diagnosing crashes and product usage.
- **Account management** — sign-up, login, profile.
- **Fraud prevention, security, and compliance** — KYC, Play Integrity, RLS.
- **Communications** — transactional email / push.

We do NOT use any data for:
- Advertising or marketing
- Personalisation beyond the user's own role/profile
- Selling to third parties
- Selling personal info

---

## Security practices

| Question | Answer |
|----------|--------|
| Data is encrypted in transit | **Yes** |
| You provide a way for users to request that their data be deleted | **Yes** |
| You commit to follow the Play Families Policy | **N/A** (not directed to children) |
| Independent security review | **No** (v1) |

---

## Founder action items inside Play Console

1. Open **App content > Data safety > Manage**.
2. Walk through every category above and tick the boxes exactly as listed.
3. The form auto-generates the public "Data safety" panel that appears on
   the Play Store listing — verify the preview before publishing.
4. If v2 adds Razorpay, **revisit "Financial info"** and add the relevant rows.
