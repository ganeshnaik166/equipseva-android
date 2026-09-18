# Handoff — backend regression suite + round 3824, 2026-09-18

Branch `backend/regression-suite` (cut from `origin/main` @ `d3a9587b`), worktree
`C:/Users/lokes/equipseva-backend-suite`. Tip `eb1f9ec7`, pushed. Tree clean.

## What shipped

**The suite** (`supabase/regression/`, documented in its own README): three catalog queries that render
the function, table and policy surface as sorted one-object-per-line TSV; a runner that drives them
against a local stack or production; a scanner that extracts every `.rpc("…")` call site in
`app/src/main`, `web/src` and `supabase/functions` with the role that client runs as; and `check.mjs`,
which joins them and fails on six shapes that have each shipped to production before (missing RPC,
ungranted RPC, `anon`-executable `founder_*`, `PUBLIC` EXECUTE, definer without a pinned `search_path`,
table with RLS off). Today's production state is the committed baseline and every accepted finding is in
`allow/` with a written reason, so the suite passes now and any new drift fails.

**Round 3824** (`supabase/migrations/20263901000000_…`), **APPLIED to production** at ~12:45 UTC and
recorded in `supabase_migrations.schema_migrations`.

## Measured facts

| | |
|---|---|
| RPC call sites scanned | 15,622 (15,565 distinct names) — 15,570 called as `authenticated`, 52 as `service_role` |
| Production surface | 19,363 public functions (19,315 SECURITY DEFINER), 4,876 tables, 3,515 policies |
| First run | **460 findings**: 27 no-grant, 7 missing, 195 anon-founder, 231 PUBLIC-EXECUTE |
| Definer functions without a pinned `search_path` | **0** |
| Public tables with RLS off | **0** |
| After round 3824 | **432**: no-grant **27 → 0**, anon-founder **195 → 194** |
| With allowlists | **PASS** |
| Replay time for a local stack | **unmeasured** — no Docker on this machine; `backend.yml`'s nightly job times it and prints the figure |

## The two real defects, and why they were invisible

1. **26 + 1 founder-console RPCs could never be executed by the console.** The console authenticates with
   the anon key plus the founder's session cookie (`web/src/lib/supabase/server.ts` — there is no
   service-role client anywhere in `web/`), so every RPC it issues runs as `authenticated`. These 27
   carried `postgres=X/postgres service_role=X/postgres`. Disputes, Finance, Health, Refunds,
   Reconciliation, Risk, DPDP, Referrals, Tiers, Chains, Investor and the engineer detail page were all
   answering 42501 to the founder. A migration that forgets a grant still runs green, which is exactly
   why this needed a ratchet rather than review.
   Fix: 26 of them already re-check `is_founder()`/`is_admin()` inside the body (the house pattern —
   the 194 sibling `founder_*` functions are even `anon`-executable and rely on the same internal gate),
   so they were granted to `authenticated`. The 27th,
   `founder_payouts_dead_letter_summary()`, had **no** internal check and reads failed-payout amounts and
   provider failure reasons, so granting it as-is would have handed that to every signed-in user; it was
   re-created with the house gate (SQL body verbatim, wrapped in plpgsql) before being granted.

2. **`founder_clv_snapshot_all_hospitals()` was reachable by `anon`.** It is SECURITY DEFINER, loops over
   every AMC hospital, `INSERT`s a snapshot row each, and swallows errors — so an unauthenticated caller
   could pump rows into `founder_customer_lifetime_value_snapshots` indefinitely. Nothing calls it (no
   cron slot, no client), so every client role was revoked and `service_role` kept.

## How the migration was proven before it touched production

`is_founder()` returns true only when `auth.email()` matches the founder address, so it is false for
service-role callers — a bare gate on a cron-called function would have broken the schedule. Neither
target is cron-called (grepped `cron-tick/index.ts` and `scripts/`), which is what made the gate safe.

1. Precondition gate inside the transaction: every target must exist, be SECURITY DEFINER, carry an
   internal founder/admin check, and not already be `anon`-executable; it also asserts it checked exactly
   26, so it cannot pass by proving nothing.
2. The whole file run against production with `COMMIT` swapped for `ROLLBACK` — clean.
3. **Three negative controls**, each a deliberately falsified assertion, each of which did fail: the
   precondition count (reported "checked 26 of 26" when told to require 99), the non-founder probe (with
   the catch removed, the raw `founder only` / 42501 escaped, proving the function really is invoked and
   really refuses), and the verify loop ("verified 26 of 26 grants").
4. Pre-change ACLs of all 28 objects captured to `C:/Users/lokes/eqs-backups/2026-09-18-acl-before-round3824.txt`.
   Exact rollback SQL is in the migration header. `supabase db dump --schema-only` is not a flag this CLI
   version accepts, so the ACL capture is the backup for what is a grant-only change.
5. Applied via `supabase db push`; all three NOTICEs fired, including "dead-letter summary refuses a
   non-founder and returns 1 row(s) for the founder".

Post-apply health: `cron_tick_runs` ids 156–159 all `ok`, including today's **daily** slot (157, 08:03
UTC) — the slot that had been red for four days before round 3822. The next hourly tick after 12:45 UTC
is the first one to run entirely under the new grants; it is worth a glance, though grants to
`authenticated` cannot affect a service-role caller.

## Round 3825 — the founder audit trigger (also applied)

A second sweep, this time `plpgsql_check` over **all 19,314 plpgsql functions** in `public`, then a second
pass over every trigger function against each relation it fires on. That second pass is the one that
matters: `plpgsql_check` refuses a trigger function with 22023 unless it is handed the relation, and there
were 77 of them, so they had never been checked.

It returned one finding, repeated on all seven audited tables: **`cannot cast type repair_jobs to jsonb`**.
`founder_audit_table_mutation()` resolved the audited row id with `(NEW::jsonb)->>'id'`, and Postgres has
no composite-to-jsonb cast — while the same function already used the correct `to_jsonb()` two blocks
later. Only the id lookup was wrong.

Why it survived: the guards above that line return early unless `auth.uid()` is present **and**
`is_founder()`. So it ran for exactly one person, and with no exception handler it did not merely lose the
audit row — **it aborted the founder's statement**. All seven tables are on the runbook's emergency path
(`engineer_payouts`, `engineers`, `repair_job_escrow`, `repair_jobs`, `profiles`, `amc_contracts`,
`amc_subscriptions`). Corroboration: all seven triggers enabled, `founder_action_log` holding five rows of
which **zero** came from this trigger.

Proven, not assumed. Inside one transaction, against a throwaway temp table carrying the same trigger: a
RED probe simulating the founder confirmed the old body fails with 42846 (and would have aborted the
migration had it not), then the fix, then a GREEN probe asserting exactly one audit row with the right
target id, `op_name` and actor, rolled back through a sentinel; post-conditions assert the cast is gone
and the probe row did not leak. Two negative controls ran first and both failed correctly, reporting the
real values (`op_name` = `probe:update`, log 5 → 6). The four NOTICEs on apply:

```
round 3825: body pinned, 7/7 triggers enabled, 0 trigger-sourced audit rows exist today
round 3825 red probe: a founder write against the current body fails with 42846, as reported
round 3825 green probe: the founder write succeeded and recorded 5 -> 6 with the right target and actor
round 3825 verified: founder writes to the audited tables no longer abort, the audit row is written, and the probe left nothing behind
```

Afterwards the scaffolding and the `plpgsql_check` extension were dropped and the result verified net
zero: extension gone, scratch tables gone, audit function cast-free, 7 triggers still enabled,
`founder_action_log` back to 5 rows.

### The other 13 error-level rows

Classified in `supabase/regression/allow/plpgsql_errors.txt`, and the classification is the useful part:

- **7 false positives** — the reference sits inside an `EXCEPTION` handler the static checker cannot see:
  the six `cron.job` / `cron.job_run_details` ones (pg_cron is Pro-only and not installed) and
  `delete_my_account`'s `storage.delete_object` call, which already falls back to
  `DELETE FROM storage.objects`. **The account-deletion path is not broken** — worth stating plainly, given
  the DPDP exposure attached to it. Each confirmed by reading the body.
- **6 genuinely dead functions** whose repair means inventing product schema (HR columns on `profiles`, a
  warranties table), so they are recorded unfixed with reasons. **Three of them are called by live console
  pages**, which can therefore only show an error:
  `founder_team_comp_summary` / `_benchmarks_list` / `_employee_deltas` from
  `web/src/app/founder-team-comp-benchmarks/page.tsx:65-67`, and `founder_calendar_burndown_summary` from
  `web/src/app/founder-calendar-burndown/page.tsx:42`. Joining plpgsql findings against the call-site list
  is what made that visible; the earlier sweep had reasonably filed them as "dead code, refuse to fix".

## CI

`.github/workflows/backend.yml`, three jobs:
- **ratchet** — no database, every PR. Rescans call sites (it does not trust the committed list) and runs
  the check against the committed baseline. This is the job that catches a client shipping a call it
  cannot make.
- **prod-drift** — nightly + dispatch, needs `SUPABASE_ACCESS_TOKEN`. Read-only production snapshot,
  ratchet, and a diff against the baseline printed into the run summary. **The secret does not exist
  yet** and no `gh` CLI is installed here, so the job guards on it and skips cleanly until someone adds
  it (`gh secret set SUPABASE_ACCESS_TOKEN`, or the repo Settings UI, with a token scoped to this
  project).
- **local-replay** — nightly + dispatch, needs Docker. `supabase start` + `db reset`, snapshot, ratchet.
  It times the replay and prints the number, which is the figure needed to decide whether this can ever
  move onto the PR path.

## Still open

- 7 × `T2-MISSING`: console pages calling RPCs that were never written
  (`log_standup_entry`, `delete_standup_entry`, `log_standup_blocker`, `resolve_standup_blocker`,
  `founder_hospital_sq_recompute_quarter`, `log_founder_hospital_sq_review_action`,
  `refine_action_backlog_customer_monthly_engineer_on_site_time_r2852`). Dead panels. Fixing them means
  writing the RPCs or deleting the pages, and `web/` is owned elsewhere — **founder decision**.
- 194 × anon-executable `founder_*` and 230 × `PUBLIC` EXECUTE: pre-existing default-ACL residue. All but
  one (`founder_okr_v2_freq_threshold`, a pure interval lookup) carry an internal gate, verified by a
  full-body scan. Allowlisted as ratchets that may shrink, never grow. Narrowing them is a large, safe,
  mechanical migration whenever someone wants it.
- Not built, each blocked on tooling this machine lacks: pgTAP behavioural RLS tests (needs a local stack
  to seed three users into), a `plpgsql_check` sweep (the extension is available but not installed —
  installing it is a founder decision), and Deno tests for the webhook HMAC gates, the `X-Cron-Secret`
  401 and Play Integrity token rejection (needs Deno; the CI runner has it).
- Rounds 3821 and 3823 on the Codex branch are still unapplied, and prod's live `register_evidence` body
  is neither version — unchanged by this work, flagged again because the evidence path depends on it.

## Environment notes for whoever picks this up

No `docker`, `gh`, `node`, `deno` or `psql` on PATH. Node is reachable as
`ELECTRON_RUN_AS_NODE=1 "<VS Code>/Code.exe" script.mjs` (Node 24), which is why the runners are
dependency-free `.mjs`. Supabase CLI is `C:/Users/lokes/supabase-cli/supabase.exe`; the token file is
`/c/Users/lokes/eqs-token.txt` (**still live — revoke it at supabase.com/dashboard/account/tokens when
this work is done**). A fresh worktree needs `supabase/.temp/` copied from another checkout or the CLI
cannot find the project ref.
