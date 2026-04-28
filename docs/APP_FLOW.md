# EquipSeva — what the app does (v1)

Plain-English walkthrough of the v1 Android app: what the product is, who
uses it, and every page a user sees from app open to sign-out.

---

## 1. One-line pitch

A mobile marketplace that connects **hospitals** that need medical-equipment
repair with **independent biomedical engineers** in their city. Hospital
posts a request → engineers nearby see it, place bids → hospital picks one
→ engineer shows up, fixes the equipment, marks it done with photos →
both sides rate each other. A founder/admin reviews engineer KYC + payouts.

---

## 2. Who uses it

Three personas, one app, role-driven UI:

- **Hospital admin** — books repair work for their facility, browses
  verified engineers, picks a bid, chats with the engineer during the job,
  rates them after.
- **Engineer (independent biomedical technician)** — submits KYC docs to
  prove qualifications, picks up nearby jobs, bids on them, does the work,
  uploads "before/after" proof photos, gets paid.
- **Founder / admin** — single user (the platform operator). Reviews
  engineer KYC submissions, resolves moderation reports, watches dashboard
  health metrics. Hidden surface, only visible to a pinned email.

A user signs up once, picks a role, and the bottom-nav + side tiles change
to show only what their role needs. A user can switch roles after
sign-up — engineer can also book repairs, hospital can also become an
engineer if they want.

---

## 3. Top-level navigation

After sign-in, the app has a **3-tab bottom navigation** plus full-screen
sub-routes that hide the bottom nav while open.

```
Bottom nav:  [ Home ]   [ Repair ]   [ Profile ]
```

- **Home** — role chooser. Three large tiles: *Book Repair* (hospital flow)
  / *Engineer Jobs* (engineer flow) / *Admin Dashboard* (founder only).
- **Repair** — engineer's "today's job board" with NEARBY count, PENDING
  BIDS count, a search bar, a radius filter (10/25/50/100/All km), a map
  with pins, and a list of open repair-job cards.
- **Profile** — user identity hero card, role badge, then sectioned rows:
  Account / Business / Support / Danger Zone.

---

## 4. Every page in the app

### 4.1 Auth flow (pre-sign-in)

1. **Welcome** — single hero screen, "Sign in" + "Create account" buttons.
2. **Sign in** — email + password fields, "Continue with Google" button
   (uses Credential Manager), "Forgot password" link.
3. **Sign up** — email + password + full name. After sign-up, user hits
   role-pick.
4. **Forgot password** — type email, fire Supabase reset link. Returns
   to Sign in.
5. **Role select** — once-per-user picker: Hospital admin / Engineer /
   Supplier / Manufacturer / Logistics. v1 actively uses Hospital +
   Engineer; the rest are placeholder rows for future expansion.
6. **First-run tour** — 3-slide product walkthrough shown once per device
   after role pick.

### 4.2 Home tab (role hub)

7. **Home** — greeting card, then three role tiles:
   - **Book Repair** → hospital flow (browse engineers, request service)
   - **Engineer Jobs** → engineer flow (jobs board, my bids, earnings)
   - **Admin Dashboard** → founder only

### 4.3 Hospital flow ("Book Repair")

8. **Engineer directory** — searchable list of verified engineers near
   the hospital. Filter by district / specialization / brand serviced.
   Each row shows name, avatar, ratings, service area, hourly rate. Tap →
   public profile.
9. **Engineer public profile** — full read-only view of an engineer:
   bio, specializations, brands serviced, OEM training badges, total jobs,
   completion rate, hourly rate, base location on a small map, service
   radius. Phone + email shown only when the hospital already has a chat
   or a past job with this engineer (relationship gate). Two CTAs:
   *Message engineer* (opens chat) / *Request this engineer*.
10. **Request service** — multi-step form to file a new repair job:
    - Equipment: brand, model, serial, equipment-type picker
    - Issue: description (free text) + up to 5 photos (camera or gallery)
    - Urgency: Same-day / Next-day / Within-a-week
    - Schedule: date + time-slot picker
    - Site: address + map pin (auto-fills via "My location" button)
    - Submit → returns the new job_number.
11. **Hospital active jobs** — list of jobs this hospital posted, grouped
    by status (Requested / Assigned / In progress / Completed).

### 4.4 Engineer flow ("Engineer Jobs")

12. **Engineer Jobs hub** — landing screen for the engineer's daily
    workflow. If KYC not yet submitted: a "Become a repairman" card with
    "Submit KYC" CTA. Once KYC is in review or verified: 5 hub tiles:
    - **Available jobs** → today's job board
    - **My bids** → bids the engineer has placed
    - **Active work** → jobs assigned to them
    - **Earnings** → this-month + lifetime payouts
    - **Edit profile** → public-profile editor
13. **Repair tab (Today's job board)** — also reachable from the bottom
    nav. Stat strip (NEARBY / PENDING BIDS), tip card, search by issue/
    brand/model, radius filter chips, a map with hospital pins inside
    the radius circle, and a feed of repair-job cards. Each card shows
    distance, urgency, equipment name, short issue, scheduled date.
14. **Repair job detail** — full job view. Banner with hospital name +
    location, status stepper (Requested → Assigned → En route → In
    progress → Completed), all the fields, all photos. CTAs depend on
    role + status:
    - Engineer + status=Requested: *Place bid* (opens bid composer)
    - Engineer + assigned to them: *Check in* / *Mark done* (opens
      completion-proof sheet for after-photos)
    - Hospital: list of all bids with engineer cards + *Accept this bid*;
      after accept *Message engineer*; after Completed *Rate engineer*.
    - Either side: *Cancel* (when status allows) / *Report* (content
      moderation).
15. **My bids** — engineer's submitted bids, grouped by status (Pending /
    Accepted / Rejected). Tap → repair job detail.
16. **Active work** — jobs assigned to the engineer that aren't done yet.
    Same card style as job board, status-coloured.
17. **Earnings** — this-month payout total, lifetime total, list of paid
    invoices, link to Bank details.
18. **Edit engineer profile** — public-profile editor: bio, hourly rate,
    service areas, specializations, brands serviced, availability
    (Available / Busy), service radius (km).

### 4.5 Engineer KYC (verification)

The KYC flow is a **2-step wizard** entered from Profile → Verification (KYC).

19. **KYC Step 1 — Personal**
    - Verification status header (3-step timeline: Submitted → Under review → Verified)
    - Banner ("In progress" / "Submitted" / "Verified" / "Rejected")
    - "How hospitals reach you": name (read-only), email (verify CTA),
      phone (optional, contact channel only — tap *Add* to OTP-verify
      via Twilio so hospitals can call/WhatsApp)
    - "Where you operate": service-address text field + map with a
      draggable pin. *My location* button asks for permission, drops a
      pin at GPS, and reverse-geocodes to auto-fill the address text.
20. **KYC Step 2 — Documents**
    - Aadhaar number (12 digits, validated)
    - Aadhaar doc upload (photo or PDF)
    - PAN number (10 chars, validated)
    - PAN doc upload
    - Trade / qualification certificate uploads (1 or more)
    - Attestation checkbox: "I confirm the above is accurate"
    - **Submit** → row created in `engineers` with status=pending,
      founder review queue picks it up.

### 4.6 Chat

21. **Conversations list** — all chat threads the user is part of, newest
    on top. Each row shows counterpart's name + avatar, last-message
    preview, unread count, time. Search bar at top.
22. **Chat thread** — message bubbles with timestamps + read receipts,
    typing indicator, sender-edit (within 15 min) + sender-delete
    (tombstone with "message deleted") menus. Text-only in v1 (no
    attachments). Tap counterpart's avatar → engineer public profile or
    hospital read-only card.

### 4.7 Notifications

23. **Notifications inbox** — feed of in-app notifications: new bid on
    your job / your bid was accepted / job reassigned / engineer marked
    done / etc. Tap → deep-link into the relevant repair-job detail or
    chat thread.
24. **Notification settings** — per-category mute toggles (Orders, Jobs,
    Chat, Account) + quiet-hours window (start time / end time).

### 4.8 Profile tab

25. **Profile** — hero with avatar, name, email, role badge, "Edit"
    button. Founder gets an extra "Founder dashboard" tile here. Below
    the hero, sectioned rows:
    - **Account**: Personal info / Add phone number (Required pill if
      missing) / Notifications / Change password / Change email /
      Appearance (Light / Dark / System)
    - **Business** (engineer): Verification (KYC) chip showing Start /
      Draft / In review / Verified / Rejected / Earnings / Bank details
    - **Business** (hospital): My repair jobs / Addresses / Hospital
      settings
    - **Support**: Help & support (mailto support@equipseva.com) /
      About / Export my data
    - **Danger Zone**: Sign out / Delete account
26. **Personal info edit** — full name, phone, save.
27. **Add / change phone number** — `+91` prefix locked, 10-digit input,
    *Send code* → 6-digit OTP screen → verify via Twilio Verify.
28. **Change password** — current + new + confirm, validation.
29. **Change email** — new email + password reauth, fires Supabase email
    confirm flow.
30. **Notification settings** — same as #24, also reachable from Profile.
31. **Bank details** — account holder, account number (encrypted),
    re-enter to confirm, IFSC, optional UPI ID. Verified flag set by
    admin only.
32. **Addresses** — saved address book; add / edit / delete. Each row
    has type (home / work / hospital site).
33. **Hospital settings** — hospital admin profile fields (org name,
    address, beds count, accreditation, GSTIN, GST certificate upload).
34. **About** — app version, build number, links to privacy policy /
    terms of service / open-source licenses.
35. **Export my data** — generates a JSON dump of everything the user
    has stored, sends to their email + offers a Share intent.
36. **Delete account** — confirmation sheet with reason field; calls
    SECURITY DEFINER RPC `delete_my_account` which cascades + signs out.

### 4.9 Founder admin (hidden, email-pinned)

Reachable only from Profile when `email == ganesh1431.dhanavath@gmail.com`.

37. **Founder dashboard** — KPI tiles: pending KYC count, open reports,
    total users, today's payments. Quick links to each queue.
38. **Engineer KYC queue** — list of pending KYC submissions. Tap a row
    to review docs, see Aadhaar/PAN, see uploaded photos, then
    **Approve** / **Reject (with reason)**.
39. **Buyer KYC queue** — same flow, hospital-side documents (GST cert).
40. **Reports queue** — content moderation reports. Each row shows
    target type (chat message / engineer profile / repair job / RFQ /
    hospital), reason, reporter notes. *Resolve* / *Dismiss*.
41. **Users** — searchable user table; can force-change a user's role
    (between non-admin enums) or block/unblock.
42. **Payments** — recent platform payments, status badges, click for
    details. Read-only view.
43. **Integrity flags** — Play Integrity / signature-verifier alerts
    (devices flagged as rooted / repackaged / replay attacks).
44. **Categories** — equipment-category seed list; founder can add /
    rename / set is_active flag.
45. **Engineers map** — heatmap-style view of engineers grouped by
    district; click a district to see counts.

---

## 5. The repair-job lifecycle

The single most important flow. Spans hospital + engineer.

```
Hospital                                 Engineer
─────────                                ─────────
posts request  ─────► status=requested  ◄─── shows up on job board
                                         │   in their radius
                                         ▼
                       status=requested  ◄─── places bid
                                         │
sees bid in detail  ─── picks one ──────► status=assigned
                                         │
                                         ▼
                                         engineer checks in
                                         status=en_route
                                         │
                                         ▼
                                         status=in_progress
                                         │
                                         ▼
                                         engineer marks done
                                         (uploads after-photos)
                                         status=completed
                                         │
rates the engineer ◄────────────────────►rates the hospital
hospital_rating                          engineer_rating
```

Either side can cancel before `assigned`/`in_progress`. Disputes can be
raised from the detail screen at any active state and route to the
founder reports queue.

---

## 6. Trust signals that show up everywhere

- **Verified-engineer badge** — engineer cards (public profile, directory,
  job board bid list) show a small green tick + "Verified" pill only
  when admin has approved KYC.
- **Verification (KYC) chip** on Profile — Start / Draft / In review /
  Verified / Rejected — colour-coded.
- **Hospital "verified-org" pill** — appears on hospital banner inside
  repair-job detail when admin has approved the hospital's GST docs.
- **Bank-account verified flag** — engineers see "Verified by EquipSeva"
  on their bank-details row only after admin clears it; until then a
  yellow pending pill.
- **Realtime read receipts + edited tag** in chat — sender's bubble shows
  "edited" when message was modified within 15 min, "deleted" tombstone
  when removed.

---

## 7. What the app deliberately does NOT do (v1)

- **No marketplace / buy-sell / cart / checkout / orders.** Spare-parts
  marketplace was scoped out of v1.
- **No Razorpay payment flow.** Engineer payouts are handled
  out-of-band by the founder for v1.
- **No phone-OTP login.** Phone is collected as a hospital-contact
  channel inside KYC, not as an auth factor. Login is email + password
  or Google.
- **No supplier / manufacturer / logistics flows.** Roles exist in the
  picker but the dedicated screens are post-v1.
- **No offline-first authoring.** Outbox handles bid + status + photo
  retries on flaky network, but the app expects users to be online for
  most flows.

---

## 8. Brand basics

- App name: **EquipSeva** (English: "equipment service")
- Primary brand colour: deep medical green `#0B6E4F` (BrandGreen)
- Accent: bright lime `#0FFF13` (AccentLime) — used sparingly on stat
  pills + active states, never on body text
- Tone: practical, hospital-friendly, no jargon. Copy is short and
  imperative ("Pin the area you serve", "Mark Done with photos").
- Iconography: Material Symbols (filled + outlined), no custom
  illustrations. Map widgets are Google Maps Compose.

---

## 9. Tech facts that affect UX

- All state is server-authoritative via Supabase Postgrest + RLS. The app
  is mostly thin views over server reads.
- Realtime subscriptions on chat conversations + chat messages +
  notifications, so live updates land without pull-to-refresh.
- Push notifications via FCM with deep-link routes; tapping a push from
  a killed-app state opens the matching screen directly (chat thread,
  job detail, etc.).
- Sign-out wipes local cache (FCM token, outbox queue, photo stash) so
  the next user signing in on the same device starts clean.
- KYC docs + repair photos are private Supabase storage buckets; the
  app mints short-lived signed URLs for cross-user views (engineer ↔
  hospital).
