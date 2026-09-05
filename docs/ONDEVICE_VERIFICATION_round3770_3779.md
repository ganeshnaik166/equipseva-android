# On-device verification of the round3770-3779 features (2026-09-05)

The nine features surfaced in `97a974e7` shipped on unit tests plus a clean
`assembleDebug`. Neither touches Postgres or a real device, so this is the
first time the screens have actually been driven and the first time their
write paths have been executed.

Emulator `eqs`, fresh `assembleDebug` at HEAD, debug build
`com.equipseva.app.debug`.

## Hospital session — `play-review-hospital@equipseva.com`

**Zero FATAL EXCEPTIONs across the whole run.**

| screen | round | result |
|---|---|---|
| Privacy & data rights (DPDP grievance) | 3776 | rendered — DPDP Act 2023 explainer, "File a data-rights request", correct "No requests filed yet." |
| Commission tier | 3773 | rendered — "7%", "10 more completed jobs unlocks 5% commission" |
| Account self-service (hospital portal) | 3778 | rendered — "New account-change request", "No account-change requests yet." |
| Your disputes | control | rendered — "No disputes filed" |
| Export my data | control | rendered — share-sheet confirmation dialog with its data-exposure warning |
| Hospital settings | control | rendered — GSTIN field with real "2-digit state + 10-char PAN + entity + Z + check digit" validation copy |

### Data correctness, not just rendering

`get_my_commission_tier()` returns `current_rate 0.07`,
`jobs_to_next_tier 10`, `next_tier_rate 0.05`. Ground truth for that
hospital is **0** completed jobs in a rolling 12 months. The screen shows
"7%" and "10 more completed jobs unlocks 5% commission" — so the
decimal→percent conversion is right and the count reconciles. This is
worth checking explicitly because the usual failure here is rendering
`0.07` as "0.07%" or "0%".

### DPDP write path — proven, because rendering proves nothing about filing

"Compliant on paper with nobody able to file" was this feature's original
defect, so the empty state rendering correctly is not evidence. Executed
against production inside a rolled-back probe:

* `file_dpdp_grievance('deletion_request', …)` inserts, `status = 'open'`
* `deadline_at` lands **exactly 30 days out**, matching the on-screen
  "We respond within 30 days" copy — backend SLA and UI copy agree
* the table went 1 → 2 while `my_grievances()` returned **1**, so RLS
  scopes to the caller and does not leak another user's request
* all six types the picker offers (`access_request`, `deletion_request`,
  `correction_request`, `data_portability`, `consent_withdrawal`,
  `complaint`) are valid against
  `dpdp_grievances_grievance_type_check`; the picker correctly omits
  `data_breach_notification`, which is an admin-side type
* probe rolled back — 0 rows left behind

### Incidentally confirmed: the round3804 CI fix

Commission tier renders "5%" and "3%" correctly. That is the empirical
proof that `formatted="false"` was right and `%%` would have been wrong —
the string is read with `stringResource()` and no format arguments, so
`getString()` never runs `String.format` and `%%` would have displayed
literally. See `docs/`-adjacent notes in the round3804 commit.

## Engineer session — `play-review-engineer@equipseva.com`

That account is `verification_status = 'verified'` with **0** KYC
renewals, **0** referrals and **0** certification-progress rows, so those
screens hit their empty state — the case most likely to crash. It does
have real work: **2** repair jobs, 1 of them `in_progress`, and the
engineer Home Hub renders them (Philips IntelliVue MX450, GE CARESCAPE
B450).

> **Correction, and a schema gotcha worth recording.** My first count of
> the engineer's jobs returned 0, which contradicted the Home Hub showing
> in-progress work. The query was wrong, not the app:
> **`repair_jobs.engineer_id` is a FK to `engineers(id)`, NOT to
> `auth.users(id)`.** Joining it against the auth user id silently matches
> nothing rather than erroring. The correct join is
> `repair_jobs.engineer_id = engineers.id WHERE engineers.user_id = <auth uid>`
> — which is exactly the shape round3781 had to repair in
> `profitability_for_repair_bid`. Treat any `engineer_id` comparison
> against a user id as a bug.

### Read paths, executed as the engineer

| RPC | result |
|---|---|
| `my_kyc_renewal()` | 0 rows — matches the "No renewal due" empty state |
| `my_referrals()` | 0 rows |
| `my_pending_referral_confirmations()` | 0 rows |
| `engineer_profile_completeness()` | 1 row |

### Engineer screens, driven on-device

| screen | round | result |
|---|---|---|
| KYC renewal | 3779 | rendered — "No renewal due · Your KYC is current. We'll notify you here about 30 days before your annual renewal is due." |
| Refer an engineer | 3777 | rendered — ₹2,000 bounty copy, "Your referral code" + Copy, paste-a-code confirm field, "No referrals yet." |
| Profile completeness | 3775 | rendered — "5%", "Incomplete", concrete missing list (photo, PAN, specialization, GSTIN, 6 jobs, police verification, service location, certifications) — reconciles with `engineer_profile_completeness()` = 1 row |
| Privacy & data rights | 3776 | rendered — same role-agnostic screen as the hospital session |

Zero app-attributable crashes across the engineer run as well.

**Two content observations, flagged rather than changed:**

1. **The KYC renewal empty state makes a promise nothing can keep yet.**
   "We'll notify you here about 30 days before your annual renewal is
   due" — but renewal rows are only created by
   `schedule_engineer_kyc_renewals`, which (a) has no scheduler
   (`docs/CRON_SCHEDULING_GAP.md`) and (b) is one of the sweep's declined
   repairs, blocked on the missing `engineers` verification-timestamp
   column. Until both founder decisions land, no engineer will ever be
   notified. The screen accurately reflects *current* state; the promise
   is about machinery that does not run.
2. **The referral "code" is the referrer's raw auth UUID.** Verified
   against the backend: `register_engineer_referral(p_referrer_user_id
   uuid)` — the code *is* the user id by round564's design, and
   round568's confirm step is what makes a known UUID non-abusable. So
   the app is correct per contract; whether a 36-character UUID is
   acceptable as a shareable code is a product call, not a client bug.

### Write paths, executed and rolled back

* `update_my_profitability_floor(1234.00)` — wrote `1500.00 → 1234.00`,
  confirmed reverted to `1500.00` after rollback
* **`register_engineer_referral(<self>)` correctly REJECTED (22023)** —
  this is round568's self-attribution-griefing control, and this app is
  the first client since that patch, so it is verified live rather than
  assumed
* `confirm_engineer_referral('00000000-…')` rejected cleanly (02000) —
  a bogus id fails, it does not crash

## Error handling reviewed across all ten new screens

All ten (`DpdpGrievance`, `CommissionTier`, `HospitalPortal`,
`KycRenewal`, `EngineerReferral`, `HospitalPmCalendar`,
`HospitalFleetHealth`, `JobProfitability`, `ProfileCompleteness`,
`HospitalTierPreview`) have a **distinct** `state.error != null` branch
with a retry CTA, separate from their empty state, plus a loading branch.

That matters because of the r1455 bug class — an empty state whose copy
asserts a data condition the section does not actually measure. If a load
failed and fell through to "No requests filed yet", the user would be told
there is no data when the truth is that the fetch broke. These screens do
not do that.

## A false crash report, and why it is worth writing down

Mid-run the harness reported `KYC renewal — *** CRASHED ***`. It had not.

The `FATAL EXCEPTION` in logcat belonged to
`com.android.commands.uiautomator`, dying with *"UiAutomationService
… already registered!"*, because two sweeps were running at once and
their `uiautomator dump` calls collided. Attribution settles it: the app
process was PID 9461 while every crash carried a different, short-lived
PID, and **`com.equipseva` appears in zero crash stacks**.

The detector was the defect — it grepped logcat for `FATAL EXCEPTION`
with no notion of which process died, so any tooling crash read as an app
crash. Corrected to
`logcat -d | grep -A30 "FATAL EXCEPTION" | grep -c com.equipseva.app`.

Two harness rules came out of it:

* **Attribute a crash to a process before reporting it.** An on-device
  harness runs several processes; only one of them is the thing under
  test.
* **Never run two UI sweeps concurrently, and never edit a shell script
  while bash is executing it.** Bash reads scripts incrementally, so an
  in-place edit made one run re-execute a section — which is why an
  earlier log shows the same screen visited twice.

This is the same shape as the round3802 finding: a check that cannot fail
correctly is worse than no check, because it manufactures confident
conclusions in both directions.

## Known gap

The **PM Calendar** and **Fleet Health** screens were not driven in this
pass. PM Calendar is separately known to render an empty calendar
permanently: `equipment_pm_schedule` has 0 rows, its populating cron does
not exist, and it projects from `dsr_reports` which also has 0 rows. See
`HospitalPmCalendarRepository`'s header and
`docs/CRON_SCHEDULING_GAP.md`.

## Addendum (2026-09-05, later): the last two screens — matrix complete

Driven via Jobs hub → My bids → **Accepted (2)** tab (the CTAs live on
accepted-bid rows, which is why earlier passes on the default Pending tab
found nothing):

| screen | round | result |
|---|---|---|
| Profitability check | 3773 | rendered — gross bid, "Platform fee (7%)", estimated travel cost, estimated net payout, plus the minimum-floor editor showing the account's real `profitability_floor_rupees` (1500) |
| Payout preview | 3774 | rendered — "Contracted amount ₹2,500", "Platform commission 7%", "Your take-home ₹2,325", with the loyalty-tier explainer |

Numbers reconcile with the backend probes: ₹2,500 × 0.93 = ₹2,325
matches `engineer_view_hospital_tier`'s round3781 live output exactly,
and the floor editor's 1500 matches the value the round3805 write probe
read and restored. Zero app-attributable crashes.

With these two, every round3770-3779 screen is on-device verified except
the two documented as structurally empty upstream (PM Calendar, Fleet
Health — see `docs/CRON_SCHEDULING_GAP.md`; their recompute sweep now
runs daily as of round3807, but PM projection stays empty until a
DSR-submission path exists).
