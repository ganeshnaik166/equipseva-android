# EquipSeva — Content Rating (IARC) Answers

For Play Console > App content > Content rating. Google routes the same
answers to IARC, ESRB, PEGI, USK, ClassInd, ACB, GRAC, and the Indian DGFT
self-declaration.

---

## Section 1 — Category

**Choose the category that best describes your app.**
- Selected: **Reference, News, or Educational** > **Other (Productivity / Utility)**.
  EquipSeva is a B2B service-marketplace; the closest IARC bucket is the
  utility / productivity branch. (Do NOT pick "Game".)

## Section 2 — Violence

| Question | Answer | Notes |
|----------|--------|-------|
| Does the app contain references to violence (e.g. fighting, weapons)? | **No** | Pure repair-marketplace UX. |
| Realistic-looking violence? | **No** | |
| Cartoon / fantasy violence? | **No** | |
| Sexual violence? | **No** | |

## Section 3 — Sexuality

| Question | Answer |
|----------|--------|
| Sexual content / nudity? | **No** |
| Suggestive themes? | **No** |

## Section 4 — Language

| Question | Answer |
|----------|--------|
| Profanity or crude humour? | **No** |
| Discriminatory or hate speech? | **No** |

## Section 5 — Controlled substances

| Question | Answer |
|----------|--------|
| References to alcohol, tobacco, or drugs? | **No** |
| Prescription / over-the-counter medication content? | **No** — we repair the equipment that delivers medication, not the medication itself. |

## Section 6 — Gambling

| Question | Answer |
|----------|--------|
| Real-money gambling, betting, or simulated gambling? | **No** |
| Loot boxes? | **No** |

## Section 7 — User-generated content & social features

| Question | Answer | Notes |
|----------|--------|-------|
| Does the app allow users to interact with each other (chat, voice, video)? | **Yes** | In-app text chat between a hospital and the engineer assigned to a job. |
| Does the app share user-generated content publicly? | **No** | Chat is private 1:1 to a single job. Equipment photos are visible only to participants of that job. |
| Does the app allow users to share their physical location with other users? | **Yes** | Hospitals share the service address (city + pincode + street); engineers share their service-area centre. Precise GPS is never shared between users. |
| Has the developer implemented moderation tools (block, report, mute)? | **Yes** | In-app **Report user** and **Block user** flows. Moderators triage within 24 hours. |

## Section 8 — Miscellaneous

| Question | Answer | Notes |
|----------|--------|-------|
| Does the app provide unrestricted access to the internet (e.g. browser)? | **Yes** | Outbound HTTP via WebView for KYC document pickers and OAuth. No general-purpose browser. |
| Does the app collect or share user location? | **Yes** | See `privacy-policy.md` §2. |
| Does the app facilitate digital purchases? | **No (v1)** | Razorpay-driven payments arrive in v2. Re-answer this question when v2 ships. |
| Does the app share personal data with third parties? | **Yes** | Supabase (backend), Google (Maps + FCM + Crashlytics + Play Integrity), Sentry (crash). Listed in privacy policy §4. |
| Does the app contain ads? | **No** | |

---

## Predicted IARC rating

**Everyone (ESRB) / PEGI 3 / IARC 3+.**

Justification:
- No violence, no sexual content, no profanity, no gambling, no controlled
  substances.
- The "social interaction" flag (chat + location share) does not by itself
  push an app past the Everyone bracket — Google's matrix only escalates
  when chat is paired with public discoverability of strangers or open
  user-to-user video. Neither applies here: chat is scoped to a single
  pre-matched job and is always between adult professionals.
- We will display the **"Users interact"** descriptor under the rating, which
  is appropriate and does not change the bracket.

If the IARC engine returns **Teen / PEGI 12** (which sometimes happens when
"shares user location" + "user-generated content" combine), accept it — the
bracket is fine for a B2B medical-procurement audience and does not require
distribution restrictions.
