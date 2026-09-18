# Handoff — quality branch, 2026-09-18

Branch `claudedev-quality-20260912`, worktree `C:/Users/lokes/equipseva-quality-20260912`.
Supersedes `docs/HANDOFF_CLAUDEDEV_QUALITY_20260912.md`. The seven audit reports this
work implements are in `docs/audit-20260917/`.

## What this branch is

The founder asked for a full code-quality audit on a separate branch, then for the findings
to be implemented. Seven audit agents produced ~120 findings; they are committed verbatim in
`docs/audit-20260917/` so a reader can check any claim against its evidence rather than
against a summary. This branch implements 95 of them across six areas: outbox/sync,
security + CI, repair/hospital flows, money + KYC, the Compose design system, and the
Supabase edge functions.

Every implementation was reviewed by a second agent that was told to find regressions in it,
and the twelve blockers those reviews raised are applied here. Three reviewer claims did not
survive checking and were not applied as written — see "Where the reviews were wrong".

## State

| | |
|---|---|
| Unit tests | 3,496 run |
| Failures | 7, all in `features.kyc.KycEmailOtpStateTest` |
| `lintDebug` | passing |
| `assembleDebug` | passing |
| CI coverage of this branch | none until the push filters land — see below |

The seven failures are email-OTP cancellation cases. They are not this branch's doing: the
same seven fail with `KycViewModel` and its test reverted to the branch tip, and they failed
on the untouched base before any of this work. The file this branch does change in that view
model is the document-orphan cleanup and a profile-fetch failure that used to be swallowed;
neither is on the OTP path. Whoever owns that coordinator should take them.

## Merge this first, separately from everything else

`android.yml`, `secret-scan.yml` and `evidence-regressions.yml` filtered pushes on the
literal branch name `claudedev-help`. Every other `claudedev-*` branch, including this one,
has therefore never been built, tested, linted or secret-scanned by CI. The filters now read
`claudedev-**`. Until that lands, treat every measurement in this document as a local one.

The same commit pins `gitleaks/gitleaks-action` to a commit rather than a moving tag, because
that action receives a token with `pull-requests: write`. The pin
`e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e` was checked against the upstream repository: it is
what both `refs/tags/v3` and `refs/tags/v3.0.0` point at. Re-resolve it at merge time if you
would rather track a newer v3 patch.

## The defects worth knowing about

**The dispatch RPC rejected the status the payouts worker asked it for.** On a Cashfree 5xx
the worker called `record_engineer_payout_dispatch` with `p_status = 'queued'`, and the
function raises 22023 for anything outside `('processing','failed','no_method')`. Confirmed
by reading the live function body in production. The call wrote nothing at all: the payout
kept the status pickup gave it, with no failure reason and no provider reference id, so the
only thing that rescued it was the reaper, and nothing recorded why. The worker now records
`processing` with a marker status and the reason, and reclaims those rows itself at the top of
each run. It runs every five minutes; the reaper sits in the cron-tick `hourly` group, which
the ledger measures firing about every three hours, and each of its passes bumps the counter
it dead-letters on — four passes turned a transient outage into a permanently failed payout
carrying raw provider text onto the engineer's earnings row.

**A hospital could agree to a four-hour emergency SLA while choosing thirty minutes.** The
AMC wizard accepted fractional response-time hours, and submit parses that field with
`toIntOrNull()`. `amc_contracts.response_time_emergency_hours` is an integer defaulting to 4,
so "0.5" arrived as null and the server wrote 4. Both the column and the RPC parameter are
integers in production, so the gate now requires whole hours. Sub-hour SLAs need a minutes
column before they can be offered.

**A job assigned to an engineer was invisible on their only list.** The active-work screen
renders two buckets and nothing else, and its query filters on `engineer_id` with no status
filter — so a visit pre-assigned rather than bid on arrives still marked `requested` and
matched neither bucket. Production holds exactly one such row today. `Requested` is now
active work, and the sweep that would have caught it is no longer allowed to exclude it.

**The AMC "never replay a deterministic refusal" rule could not fire.** It matched
`HTTP 4\d\d` against the exception message, and `verify-amc-payment` answers every refusal
with a parseable `{ ok, code, message }` body, so the parsed copy replaced the status and the
pattern never matched a real response. Every server refusal was replayed twice with backoff,
in both the sheet and the wizard. The status now travels as data on a typed exception. Its
test passed the whole time, because it hand-wrote messages containing "(HTTP 400)".

**A rejected check-in photo destroyed the engineer's selection.** Confirm closed the check-in
sheet before the view model could refuse, and the picked photos were remembered inside the
sheet, so the refusal copy ("try a smaller photo, then tap again") pointed at a button that
no longer existed. The sheet's lifetime is now view-model owned, like the completion sheet's,
and closes only past every refusal.

**The AMC failure message was written where nobody could read it.** Moving the charge to the
view-model scope was right — money in flight has to outlive the sheet — but the failure copy
still went to state the sheet rendered, so it reached a sheet that had already gone and then
fired as a stale toast the next time one opened. It travels as an effect now, on the same
channel as the two success outcomes, collected by the screen.

**Two more, from the tests they broke:** a KYC document whose provider reports an unknown
size was rejected as oversize before a byte was read, because the validator answers
`TooLarge` for a non-positive size; and a signed-in engineer whose first status fetch failed
was shown the "Sign in" hero with no retry, because the session state `NotSignedIn` was being
treated as a verification result worth preserving.

## Where the reviews were wrong

Worth recording, because it is the argument for checking a reviewer the way you check an
implementer.

**Compose touch targets.** Three new 48dp assertions failed, and the reviewer's diagnosis of
why was right: `minimumInteractiveComponentSize` had been placed outside the clickable, so it
reserved layout space while the hit area stayed the size of the paint. Confirmed from the
Material3 bytecode, where that node implements only `LayoutModifierNode`. The reviewer then
said the framework already expands a clickable's hit area to 48dp, which would have made the
whole change cosmetic; that is half true. The expansion lives in Compose UI's hit testing, as
a fallback when no node is hit exactly, so it loses to a nearer sibling in a row of chips. The
fix kept here puts the minimum on the node that takes the tap and hands the ripple back to the
painted pill through a shared interaction source, so the paint and the ripple shape are
unchanged and the target is not fallback-dependent. The same treatment went to the founder
console's two pill chips, the notification toggle and the inbox icons, the last of which keeps
its designed 36dp state layer.

**The active-work test.** The reviewer said its own new exhaustiveness test failed as written.
It did, but the reason mattered more than the reviewer said: the honest fix was the bucket,
not the test, and the ledger's correction (delete the test that pins `Requested` as
unbucketed) is what was applied.

**The outbox retry policy.** The reviewer proposed making the retry decision per-actionability
rather than per-batch. The stronger and simpler answer is that this worker must never report
`retry` at all: the one-shot request is enqueued with `APPEND_OR_REPLACE`, a dependent runs
only once every prerequisite has SUCCEEDED, and an entry that keeps deferring would hold a
brand-new chat message BLOCKED behind it on a healthy network while the head's backoff doubled
toward WorkManager's five-hour ceiling. Re-attempts come from the periodic tick and the next
enqueue, which is what the class documented before the change.

**The queueable-failure predicate.** `isNetworkFailure` justified itself with a claim about
the drain that was false — the drain does not give up on every 4xx, it retries 401, 408, 429
and every 5xx. Writes that hit those were being discarded instead of queued, including every
write during the roughly nineteen seconds a PostgREST schema-cache reload answers 503. The
predicate now names those statuses, and a test compares its list against the drain's own
classifier so the two cannot drift apart again in silence.

## Ratify or revert — these are judgement calls, not fixes

- **Poison threshold.** A queued write now needs 20 failed attempts *and* 24 hours in the
  queue before it is dropped, so an outage can no longer empty the queue. A genuinely dead row
  lingers up to a day, and the "couldn't send" notification arrives later than it used to.
  Permanent refusals are unaffected; they still leave on first sight.
- **One-way risk in the same area.** If a session can never be restored (a revoked refresh
  token) while rows are queued, the worker defers forever rather than dropping them after
  about 75 minutes. A real sign-out clears the queue, so this only bites that one state.
  Bounding it needs an age-based sweep, not the attempts budget.
- **Evidence registration.** After a successful photo upload, failing to queue the section 65B
  evidence row now reports Retry rather than success, so a photo cannot sit on a job with no
  ledger row. The cost is one repeated upload in a rare failure mode. Four assertions in the
  frozen evidence integration test were flipped to match; the single thing to revert is the
  `reportAndGiveUp` helper.
- **Database recovery.** When the Keystore key is gone the app now deletes the local database
  instead of crash-looping, which discards queued outbox writes in it. The audit's reasoning
  is that the database is cache plus outbox and never canonical state. It is still a trade.
- **Symbolication.** `mapping.txt` is no longer published as a build artifact or attached to a
  release, because this repository is public and the map de-obfuscates the bundle sitting next
  to it. Sentry's upload only runs when `SENTRY_AUTH_TOKEN`, `SENTRY_ORG` and `SENTRY_PROJECT`
  are set on the release job. Confirm those three before the next tag, or a shipped build's
  mapping will exist nowhere.
- **Cron logs.** A failed hourly, code-red or payouts run now prints only the HTTP status,
  because the bodies named payout ids and provider reference ids on a public repository.
  Diagnosis moves to `cron_tick_runs` and the payout rows.
- **Play review.** 26 `<package>` entries were added to the manifest as the review-friendly
  alternative to `QUERY_ALL_PACKAGES`, which the detector needed: package-visibility filtering
  made every probe report "not installed", so the tamper check could never fire. Reviewers can
  see that list and sometimes ask why an app wants to know about Magisk. The answer is the
  anti-tamper layer. Enforcement is still off in release builds.
- **Copy.** "Try again" became "Retry" on two error states, because that was the only shared
  string available without adding one.

## Founder or Codex decisions, unchanged by this pass

- **A Google-only account still cannot delete itself.** The half-built passwordless path was
  unreachable dead code and has been removed; what remains is the honest error copy naming the
  provider. Closing the DPDP hole means letting the delete sheet re-authenticate through a
  fresh Google token instead of asking for a password that never existed.
- **`payment_capture: 1` has never been sent to Razorpay from this repository.** Create one
  sandbox order through each of the three order creators before promoting. If the account's API
  version rejects the field, all three start answering 502 and no hospital can pay.
- **The Cashfree payouts webhook mixes contract versions** — V2 headers, V1 body, V1 dispatch.
  Capture one real sandbox `TRANSFER_SUCCESS` and commit to one version end to end. Separately,
  an unrecognised body returns 200 today, and a silent acknowledgement is indistinguishable
  from success, so Cashfree stops retrying.
- **Three migrations are described but not written**: widening the dispatch RPC's status
  whitelist to include `queued` (which would let the worker drop its marker-status workaround),
  a uniqueness constraint that kills Play Integrity token replay, and chat-message idempotency.
- **Translations.** The Hindi and Telugu copies of the 17 new keys are the English text
  verbatim and need a native speaker. That is the same gap that covers roughly 709 existing
  keys.
- **Edge functions have no tests at all** and no Deno step in any workflow. The three
  highest-value pins are the dispatch-status classifier, the duplicate-transfer detector and
  the webhook event map; they need the pure helpers moved into `_shared` first, because
  importing an `index.ts` starts its `serve()`.

## There is no screenshot gate in this repository

Worth stating plainly, because two earlier handoffs imply otherwise and a "re-record the
goldens" task was queued off it. `roborazzi` appears in three audit documents and two UX plan
documents, and nowhere in any Gradle file, the version catalog, the eleven workflows or any
test. There is no Paparazzi and no capture call. The 38-entry list the batches produced is
therefore an on-device eyeball list, and the capture list for a gate somebody still has to
build. The design-system changes it names are real and visible: the top bar and bottom nav
became minimum heights rather than fixed ones, a clickable chip now sits in a 48dp box so rows
of filters grow about 16dp taller, and the 840dp tablet cap in `maxContentWidth` is effective
for the first time because its modifier order was wrong.

## Also fixed, briefly

A dependency-confusion hole: `settings.gradle.kts` searched an unfiltered ktor EAP repository
for every coordinate the two real ones did not serve. Every catalog coordinate resolves from
Maven Central, verified against the repository itself, so the extra host is gone. Three
workflows gained an explicit read-only token scope. The founder category sort-order field
stopped truncating the seventh digit and stopped refusing to save a legacy row whose ordering
predates the six-digit rule the client had invented; the bound is now the column's. The escrow
refund promise in the cancel sheet is paise-exact rather than truncated down.
