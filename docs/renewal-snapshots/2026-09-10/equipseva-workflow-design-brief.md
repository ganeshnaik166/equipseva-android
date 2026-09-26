# EquipSeva: first prototype workflow brief

7 September 2026 · M2a preparation — NOT ACCEPTED · source snapshot `05b73b522181145b1fabf3e4a2ae4d79096dd2b2`.

**Observed** means inspected source behavior, not new end-to-end or production verification. **Proposed** means a design to validate before implementation. No app score is assigned.

## 1. Entry, recovery and workspace

**Observed.** Email/password and Google are implemented through separate handlers; Google uses Credential Manager's explicit Google option. Password reset sends an email to the hosted reset page, where the user changes the password and then returns to app sign-in. It is not currently an in-app reset/deep-link completion flow. Sources: `app/src/main/kotlin/com/equipseva/app/features/auth/SignInViewModel.kt:71,91`; `features/auth/google/GoogleSignInClient.kt:60`; `core/auth/SupabaseAuthRepository.kt:89`; `docs/auth/reset.html:188,205,212`. Short paths below share the same `app/src/main/kotlin/com/equipseva/app/` prefix.

Session resolution distinguishes Loading, SignedOut, NeedsRole, NeedsOnboarding and Ready (`features/auth/SessionViewModel.kt:145–167`). It prefers server-confirmed active role over the legacy scalar role (`:248–251`). Current onboarding is a global gate: phone, state and district; engineers additionally require both UPI and bank methods. The model temporarily treats an unloaded payout-completeness value as not blocked, so a visual design must distinguish **checking** from **complete** (`core/data/profile/Profile.kt:50–79`). A stored phone number is not SMS verification (`features/profile/AddPhoneScreen.kt:53,154`). Profile role changes add a permitted role if necessary, then call `setActiveRole` before changing local state (`features/profile/ProfileViewModel.kt:210–234`). The default tab mapping falls through to engineer-shaped tabs for unknown roles; that is presentation, not proof of engineer eligibility (`navigation/MainNavGraph.kt:106–112`).

The route inventory found that `NeedsRole` currently reaches main at cold start
and is treated as authentication success after sign-in; the existing role-choice
screen is not mounted by the active root graph (`navigation/AppNavGraph.kt:121,291`).
Signup role-write failure also lacks visible retry in its completion path
(`features/auth/SignUpViewModel.kt:129–156`). These need regression-driven fixes
before treating role selection as a working flow. Separately, Welcome → Create
account → Sign in can do nothing: the callback only pops to a sign-in entry
that is absent on that path (`navigation/AuthNavGraph.kt:29–46`). Test both signup
entry paths and Back behavior before correcting the fallback.

**Proposed first screens.** One welcome screen with a short purpose statement, **Continue with Google**, **Continue with email**, and secondary account creation/help. Keep existing passwords and the explicit Google account picker. Email opens a focused sign-in form with visible password recovery. Recovery prototypes cover email sent, invalid/expired link, password saved and return to sign-in; preserve the hosted handoff until a separately tested native replacement exists. Do not add SMS-only login, passkeys or account merging to this prototype.

Existing identities restore the confirmed workspace and authorized intended task. Unknown role gets “Choose your workspace”: “I manage equipment” / “I repair equipment.” Profile shows identity and workspace, distinguishing switching from adding a role. Founder access stays privileged. Public screens contain product/coverage explanation; private jobs, sites, messages and documents stay authenticated.

Role creation or switching must receive server success before opening that workspace; missing or failed role resolution needs an explicit retry state. Sensitive account changes must use provider-aware fresh authentication: Google users must not be forced through a password-only check (AUTH-01/AUTH-02 in the master plan).

Prototype progressive readiness as a **proposed** alternative to today's global gate: explain each missing requirement at the relevant action, preserve entered work, and offer the exact setup destination. Until the eligibility matrix and backend behavior are accepted, preview this with synthetic data and keep current production gates. No new route may bypass KYC or payout requirements.

## 2. Hospital: request → compare → track → review

**Observed.** Hospital tabs are already Home / Bookings / Messages / Profile (`navigation/MainNavGraph.kt:109–110`). Home's booking action opens the engineer directory (`:321`). The public profile deliberately opens a generic request (`:478–480`) and accurately labels its action “Post a repair job” (`features/repair/directory/EngineerPublicProfileScreen.kt:659`); dropping that callback's engineer argument is not by itself a booking defect. The concrete mismatch is the completed-job “Book this engineer again” action (`features/repair/RepairJobDetailScreen.kt:2200`): its ID populates a “Booking <name>” header, but `RepairJobDraft` creation has no selected-engineer field (`features/hospital/RequestServiceViewModel.kt:853–870`). Correct the promise or separately design a server-validated invitation contract; merely passing an ID does not establish direct assignment. Request submission requires phone presence, a visit selection, an issue of at least ten characters and an address of at least five (`:780–819`). The c71 security slice scopes draft recovery, picker results and saved form state to the account/session and exposes draft retry failures (`:226–251,300–427`).

**Proposed screen structure and primary actions.** Retain the existing four tabs. Home leads with **Request service**, followed by the most urgent active commitment and recent bookings; equipment/AMC remain reachable below. Direct request becomes one tap from Home; engineer browsing stays secondary. Build a compact, sectioned request screen—Equipment, Issue/photos, Visit/site—then an explicit **Review request** step and **Submit request** confirmation. Preserve optional/unknown serial handling and current required fields. Confirm with the server-issued job number, then **View request**; draft saved is never labeled request submitted.

Bookings opens the selected job's stable summary: equipment/site, current status, responsible person, next action, timeline and Messages. For unassigned marketplace requests, **Compare bids** shows scope, amount, stated arrival estimate, qualifications and relevant history without inventing ratings or ranking new engineers as unsafe. **Review bid** precedes the consequential **Accept bid** action. Currently acceptance occurs before the checkout summary opens (`features/repair/RepairJobDetailViewModel.kt:1031–1074`); moving review earlier is a proposed behavior change, not a relabeling of that existing sheet. Acceptance, payment and starting work remain distinct states.

Assigned work prioritizes quote confirmation, visit tracking, report review or problem resolution. Keep cancellation/help/dispute reachable. Completed work offers payment status, rating and repeat booking. AMC keeps its contract/assigned-visit journey; current bid sections exclude assigned AMC jobs (`features/repair/RepairJobDetailScreen.kt:3324–3335`).

## 3. Engineer: discover → bid → perform → evidence → payout

**Observed.** Engineer tabs are Home / Jobs / Earnings / Profile; Jobs currently opens a chooser hub (`navigation/MainNavGraph.kt:98–112`). The Jobs tab blocks pending/rejected/missing KYC (`:247–260`), while Home's “Find work” enters that hub (`features/home/HomeHubScreen.kt:298–307`). The hub independently renders work tiles only for Verified (`features/engineer/EngineerJobsHubScreen.kt:209`), so this is not evidence of a KYC bypass. The inconsistency is snackbar versus recovery screen; additionally, a hub fetch error becomes `NotEngineer` (`:106`) and can incorrectly suggest KYC onboarding. Add an explicit retryable Error state and consistent recovery. Placing a bid rechecks phone presence and verified KYC (`features/repair/RepairJobDetailViewModel.kt:457–479`). Check-in/mark-done buttons require the assigned engineer, including direct AMC assignment (`features/repair/RepairJobDetailScreen.kt:2085–2100`).

**Proposed.** Prototype Today / Jobs / Earnings / Profile. Today contains genuinely dated/overdue commitments and the next action; never label all available jobs “today.” Jobs groups Available / My bids / Active with remembered filters and a Messages shortcut. Available cards show equipment fit, approximate area, urgency and stated budget; exact site/contact visibility keeps existing authorization. Detail leads to **Prepare bid**, then explicit amount/scope/arrival review and **Submit bid**. A pending bid can be edited or withdrawn; queued submission stays distinguishable from a server-confirmed bid. Estimated net earnings must expose their assumptions and remain separate from actual payout.

Assigned detail presents **Check in**, then work/proof and **Prepare service report**. GPS/geofence and before-photo collection already exist (`features/repair/RepairJobDetailViewModel.kt:655–712`); show permission denied, outside-site, queued upload and retry states instead of a false check-in success. Report UI distinguishes an absent report, engineer editing, awaiting hospital sign-off and signed/read-only record (`features/repair/DsrScreen.kt:196–234,473–483,541`). Hospital review/countersign and revisions remain explicit human actions; do not invent evidence or automatic signatures. Completion and payout are separate milestones.

## 4. State contract for every prototype branch

| Situation | Required visible behavior and next action |
|---|---|
| Loading / partial refresh | Skeleton for first load; retain authorized existing content during refresh, mark stale sections and retry that section. A failed request is not an empty list. |
| Empty / filtered empty | Explain “no bookings,” “no matching jobs,” or “no bids yet” specifically. Offer Request service, clear/widen filters, or request review; no invented arrival guarantees. Existing filtered-empty examples: `features/hospital/HospitalActiveJobsScreen.kt:112–123`; `features/repair/RepairJobsScreen.kt:212–220`. |
| Offline / pending | Distinguish local draft, queued bid, uploaded photo, attached photo, evidence registered and payment pending. Existing bid failure currently queues with an “Offline” message (`features/repair/RepairJobDetailViewModel.kt:501–504`); classify retryable network failure versus validation/authorization before carrying this pattern into the redesign. |
| Interrupted / error | Resume only the same authorized user's work. Draft Retry/Keep/Discard, re-pick after unverifiable media restoration, permission recovery and safe reauthentication are explicit. Check server outcome before retrying acceptance/payment/submission after a lost response. |
| Business exception | Give no-bid, withdrawn bid, no-show, reschedule, quote revision, unavailable signer, cancellation, dispute and overdue AMC their own actor/state/next-action explanation. Keep deadlines and money consequences based on actual policy. |

Payment copy must distinguish awaiting payment, funds held, release and payout failure; current source already handles these separately (`features/repair/RepairJobDetailScreen.kt:3152–3190`). A displayed 48-hour release statement is source copy, not newly verified provider/legal policy. Likewise, photo upload is not proof registration: attachment/enqueue failures remain a separate reliability review (`core/sync/handlers/PhotoUploadOutboxHandler.kt:125–151,214`). No prototype success state closes those engineering findings.

## 5. Prototype decisions now; human dependencies remain named

Proceed with synthetic fixtures, Seva green, Material 3 sections, one primary CTA, 48dp targets, 2x-text and English/Hindi/Telugu variants. Prototype entry/recovery, both homes, request/review, bids, assigned work/proof, report review and payment/error branches. Freeze each action's actor, precondition, resulting state and recovery before polish. Expert review can advance M2a and reversible preparation. `equipseva-route-inventory.md` now records the bounded entry/Home/request inventory and five regression targets; remaining modules and runtime journeys still need review.

Human/business dependencies: confirm readiness policy per action (especially viewing work versus bidding), direct-engineer booking semantics, payment/provider activation and time/fee/refund promises, hospital multi-staff/site permissions, and representative user recruitment. Keep current rules or clearly unactivated synthetic states while these are unresolved. M2b still needs at least five representative people per role, with recorded task completion/wrong turns/time and zero critical errors; agent agreement cannot replace that evidence. No whole-workflow acceptance or release claim follows from this brief.
