# Founder decision backlog — from the 2026-07-17/18 quality mega-session (r1477–r1504)

28 ships landed (perf, ~10 user-visible bugs, error-copy overhaul, money-path
observability, CI drift guards, marketplace E2E unblocked, release pipeline
validated). Everything self-serve is done. The items below are the ones that
need **your** call or access — each unblocks a concrete next tranche of work.

## 1. Razorpay test cards → unlocks every remaining job state
The marketplace E2E now runs end-to-end (post → bid → accept) — job
**RPR-00040** sits at Assigned with a ₹2,500 escrow awaiting payment on the
play-review accounts. With test-mode card/UPI details I can drive the payment
leg and then audit the never-reached states with real data: EnRoute →
InProgress → Completed, DSR, invoice, payout rows, escrow release/dispute.
*(Also confirm whether the debug build points at a Razorpay TEST key.)*

## 2. AMC visits — RESOLVED (r1516): `Requested` is intentional; CTA fixed
Investigation answered the question from the server design itself: `requested`
on AMC visits is load-bearing — the round446 SLA-breach sweep counts exactly
the still-`requested` visits as "engineer never responded", and the round452
FSM sanctions `requested → assigned` as the engineer's first flip (check-in
can't be first: it requires an accepted bid, which visits never have).
Shipped: the assigned engineer now sees a **"Confirm visit"** CTA (flips
Requested → Assigned, offline-queue safe, precise engineers-row-id gating);
bystander engineers get no CTA instead of the absurd "Place bid". No backend
change needed.

## 3. Server-side leads found while testing (not client bugs)
- **Graduation RPCs throw for a fresh verified engineer** — `my_supervision_
  graduation_status` + `my_tier_earnings_projection` error (not empty-return)
  for play-review-engineer, so Tier progress / Earnings projection show error
  states. UPDATE (r1516 analysis): both fns were audited in-repo and are
  null-safe — the ladder seeds a 'none' tier (display_order 0) and the
  graduation fn has an explicit no-progress-row baseline. The live failure is
  therefore NOT explainable from this repo: check whether prod has migrations
  round578/round587 applied, and pull the Postgres logs for the actual error
  when play-review-engineer opens Tier progress.
- **Code Red feed errored for the same account** (before a service location
  was set) — probably the same class; re-check after the RPC fix.
- **Junk test jobs on play-review-hospital** ("Yyyy Shah", "Shsj Zjsj",
  gibberish addresses, 7w old) — this is the Play-review account; reviewers
  see them. Worth deleting server-side for a clean review experience.
- **GST model is INCLUSIVE** (charge = bid verbatim; invoice reverses /1.18).
  r1499 fixed the client's fabricated additive display. If you ever intend
  GST to be additive on top of bids, that's a server + pricing decision —
  today's server never adds it.

## 3b. Growth lever: new-job push for engineers — SHIPPED, pending your deploy
r1514 authored the full pairing, ready for review before you apply migrations:
- `supabase/migrations/20261484000000_round1514_new_job_engineer_push.sql` —
  AFTER INSERT trigger on repair_jobs: pages up to the 50 nearest VERIFIED
  engineers within their own service_radius_km of the job site. Conservative
  v1: only open marketplace jobs (Requested + unassigned), only jobs with
  coords, never the posting hospital, exception-wrapped so job posting can
  never fail. Kind: `repair_job_new_nearby`.
- Client: deep-link → job detail (Place bid), inbox icon, tests; the
  NotificationKindDriftGuardTest enforces the pairing in CI.
REVIEW POINTS FOR YOU: targeting radius policy (engineer's own radius,
fallback 25 km), the 50-engineer cap, and whether you want quiet hours before
enabling. The trigger goes live only when you deploy migrations.

## 4. Product nits parked (cheap, need only your taste)
- Earnings banner says "verify your UPI … set up your payout method" even
  when a method exists but is unverified — sub-line wording.
- Engineer "Edit profile" service-areas hint is hardcoded "Telangana
  districts" (deliberate launch scoping; revisit when expanding states —
  the directory district filter is Telangana-only).
- Hospital "Open" count includes AMC visits (consistent everywhere, but
  debatable semantics).

## 5. hospital_pending_escrows RPC — SHIPPED (r1515), pending your deploy
Migration 20261485000000 + Home banner: accepted-but-unpaid jobs now get a
"Complete payment for RPR-NNNNN — ₹X" banner on hospital Home (tap → the
job's Pay CTA). Renders only once the migration is deployed; until then the
RPC call fails quietly and Home is unchanged. Pairs with the r1509 Bookings
badge.

## Standing references
- E2E recipe + test-account state: memory `emulator-verify`
- All bug classes + guards: memory `screen-ux-audit`, `error-copy-mapping`,
  `observability-reporting`, `perf-serial-load`
- Release pipeline: APK + AAB validated green at r1504 (`PRECHECK_LOOSE=1`).
