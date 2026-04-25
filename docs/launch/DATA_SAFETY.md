# Play Store Data Safety form — EquipSeva

This is the answer key for the Google Play Console **Data safety** section. Copy each line into the matching field.

Legend:
- **Collected** = the App sends it off the device.
- **Shared** = it is sent to a third party that is not a service provider acting only on our behalf.
- **Required** = the user cannot use the App without providing it.
- **Optional** = the user can refuse and still use the App.

In transit: **all data is encrypted via HTTPS/TLS 1.2+**.
At rest: device storage uses **SQLCipher + EncryptedSharedPreferences + Android Keystore**; server storage is encrypted at rest by Supabase / Google.
Deletion: users can request deletion in-App (Profile → Privacy → Delete my account) — answer **YES** to "Can users request that their data be deleted?"

---

## Data types collected

### Personal info

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **Name** | Yes | No | Required | Account management; communications between users |
| **Email address** | Yes | No | Required | Account management; sign-in |
| **User IDs** (Supabase user UUID, FCM token) | Yes | No | Required | Account management; analytics; fraud prevention |
| **Address** (shipping) | Yes | Shared with seller for fulfilment | Optional (only when ordering) | Order fulfilment |
| **Phone number** | Yes | No | Required | Account management; customer support |
| **Race and ethnicity** | No | — | — | — |
| **Political or religious beliefs** | No | — | — | — |
| **Sexual orientation** | No | — | — | — |
| **Other info** (Aadhaar / PAN / DL number — KYC) | Yes | No | Required for engineers + suppliers | Account management; fraud prevention; legal compliance |

### Financial info

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **User payment info** | **No** — handled entirely by Razorpay SDK; we never see card / UPI / netbanking credentials | — | — | — |
| **Purchase history** | Yes | No | Required (consequence of using the marketplace) | Account management; customer support |
| **Credit score** | No | — | — | — |
| **Other financial info** | No | — | — | — |

### Health and fitness

| Type | Collected |
|---|---|
| Health info | No |
| Fitness info | No |

### Messages

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **In-app messages** (chat between users) | Yes | Shared with the conversation partner only | Optional | App functionality |
| **Emails** | No | — | — | — |
| **SMS / MMS** | No | — | — | — |

### Photos and videos

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **Photos** (KYC selfie, KYC ID document, repair-job photos, listing photos, equipment-scan photos) | Yes | KYC photos: not shared. Listing/repair photos: visible to the conversation partner. | Required for KYC; optional otherwise | Account management; app functionality; fraud prevention |
| **Videos** | No | — | — | — |

### Audio files

| Type | Collected |
|---|---|
| Voice / sound recordings | No |
| Music files | No |
| Other audio | No |

### Files and docs

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **Files and docs** (KYC ID document upload) | Yes | No | Required for KYC roles | Account management; legal compliance; fraud prevention |

### Calendar

| Type | Collected |
|---|---|
| Calendar events | No |

### Contacts

| Type | Collected |
|---|---|
| Contacts list | No |

### App activity

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **App interactions** (screens visited, taps — anonymised) | Yes | No | Optional | Analytics |
| **In-app search history** | Yes | No | Optional | Analytics; app functionality |
| **Installed apps** | No | — | — | — |
| **Other user-generated content** (listings, RFQs, bids, reviews) | Yes | Shared with relevant counterparties | Required for posting | App functionality |
| **Other actions** | No | — | — | — |

### Web browsing

| Type | Collected |
|---|---|
| Web browsing history | No |

### App info and performance

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **Crash logs** | Yes | Shared with Sentry + Firebase Crashlytics (service providers) | Optional | Analytics; bug-fixing |
| **Diagnostics** (cold-start time, OS, device model, app version) | Yes | Service providers above | Optional | Analytics |
| **Other app performance data** | No | — | — | — |

### Device or other IDs

| Type | Collected | Shared | Required | Purposes |
|---|---|---|---|---|
| **Device or other IDs** (FCM registration token, Android ID — only via Firebase) | Yes | Service providers (Firebase, Sentry) | Optional (you can disable push in Settings) | App functionality (notifications); fraud prevention |

---

## Security practices

- **Data is encrypted in transit:** YES (TLS 1.2+ on all server traffic).
- **Users can request that their data be deleted:** YES (Profile → Privacy → Delete my account; DPDP §12 compliant).
- **Independent security review:** _[answer based on actual third-party audit status; default to NO unless one has been done]_
- **App follows Google Play Families Policy:** No (App is for users 18+, not for children).

---

## Children

- **Target audience:** 18 and over.
- **Designed for Families programme:** Not applicable.
