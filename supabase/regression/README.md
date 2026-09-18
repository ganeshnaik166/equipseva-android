# Backend regression suite

Gives the SQL/RLS/grant surface the same kind of gate the UI got from screenshot tests. Every check here
exists because the shape it forbids has already shipped to production at least once:

| check | the defect it forbids |
|---|---|
| `T2-MISSING` | a client calls `.rpc("name")` for a function that does not exist — PostgREST answers PGRST202 and the screen is dead |
| `T2-NO-GRANT` | the function exists but the role that client runs as holds no `EXECUTE` — a silent 42501 on every call, which is how 26 founder-console pages sat broken |
| `T1-ANON-FOUNDER` | a `founder_*` function is executable by `anon`, i.e. one edit away from an unauthenticated read of founder data |
| `T1-PUBLIC-GRANT` | `EXECUTE` granted to `PUBLIC`, which is how Supabase's default privileges publish a freshly created function unless the migration revokes it |
| `T4-NO-SEARCH-PATH` | a `SECURITY DEFINER` function without a pinned `search_path` — privilege escalation via a schema the caller controls |
| `T5-RLS-OFF` | a public table with row-level security disabled — readable by every authenticated user through PostgREST |

## Layout

```
supabase/regression/
  snapshot/functions.sql            one row per function overload: signature, language, kind, secdef,
                                    volatility, owner, proconfig, PUBLIC/anon/authenticated/service_role
                                    EXECUTE, body md5
  snapshot/tables.sql               one row per table: rowsecurity, forcerowsecurity, owner, policy
                                    count, per-role table privileges
  snapshot/policies.sql             one row per policy: command, permissive, roles, normalised USING and
                                    WITH CHECK text
  snapshot/run.mjs                  runs each .sql through the Supabase CLI, writes sorted TSV
  snapshot/scan_rpc_callsites.mjs   every .rpc("…") call site in app/src/main, web/src and
                                    supabase/functions, with the role that client runs as
  baseline/*.tsv                    the committed truth, captured from production
  allow/*.txt                       accepted findings, one name per line, each block with a written reason
  check.mjs                         the ratchet: joins the above and exits non-zero on anything new
```

TSV with one object per sorted line is deliberate. At 19,363 functions and 3,515 policies a JSON dump is
unreviewable, while `git diff` over sorted lines reads as "which object changed".

## Running it

```bash
# no database needed — checks the call sites against the committed baseline
node supabase/regression/snapshot/scan_rpc_callsites.mjs --repo . --out supabase/regression/baseline
node supabase/regression/check.mjs

# against production, read-only (needs supabase link + SUPABASE_ACCESS_TOKEN)
node supabase/regression/snapshot/run.mjs --target prod --out /tmp/prod
cp supabase/regression/baseline/rpc_callsites.tsv /tmp/prod/
node supabase/regression/check.mjs --snapshot /tmp/prod --json /tmp/prod/findings.json

# against a local stack (needs Docker)
supabase start && supabase db reset
node supabase/regression/snapshot/run.mjs --target local --out /tmp/local
```

`SUPABASE_BIN` overrides the CLI path. On a machine with no Node on PATH,
`ELECTRON_RUN_AS_NODE=1 "<VS Code>/Code.exe" script.mjs` works (which is why the runners are `.mjs` with
no dependencies).

CI is `.github/workflows/backend.yml`: a DB-free `ratchet` job on every PR, plus nightly `prod-drift`
(read-only snapshot diffed against the baseline) and `local-replay` (replays every migration into a fresh
stack) jobs. The replay is nightly rather than per-PR because nobody has measured its cost yet — the
workflow times it and prints the number to the run summary, so after the first nightly run there is a real
figure to decide with.

## First run, 2026-09-18

Against production: **460 findings**, of which two classes were live breakage rather than drift.

- **27 × T2-NO-GRANT.** The console authenticates with the anon key plus the founder's session cookie
  (`web/src/lib/supabase/server.ts`), so its RPCs execute as `authenticated`, but these 27 carried
  `EXECUTE` for `service_role` only. Disputes, Finance, Health, Refunds, Reconciliation, Risk, DPDP,
  Referrals, Tiers, Chains, Investor and the engineer detail page were all answering 42501 to the founder.
  Fixed in round 3824: 26 of them re-check `is_founder()`/`is_admin()` internally and were granted to
  `authenticated`; the 27th (`founder_payouts_dead_letter_summary`) had no internal check at all, so it
  gained the house gate before being granted. Re-measured after applying: **0**.
- **1 × T1-ANON-FOUNDER that was not merely drift.** `founder_clv_snapshot_all_hospitals()` is a
  `SECURITY DEFINER` function that loops over every AMC hospital and `INSERT`s a snapshot row per
  hospital, swallowing errors, and `anon` could execute it — an unauthenticated caller could pump rows
  into `founder_customer_lifetime_value_snapshots` at will. Nothing calls it, so round 3824 left
  `service_role` and revoked every client role. Count went 195 → 194.

Still open and allowlisted with reasons: 7 × `T2-MISSING` (console pages calling RPCs that were never
written — dead panels, `web/` is owned elsewhere), 194 × `T1-ANON-FOUNDER` and 230 × `T1-PUBLIC-GRANT`
(pre-existing default-ACL residue; all but one carry an internal gate, verified by a full-body scan).
`T4-NO-SEARCH-PATH` and `T5-RLS-OFF` were **zero** — that is worth keeping.

## Refresh rule

A file under `baseline/` changes **only** in the commit that intentionally changes the schema, and that
commit's message must name the objects that moved and why. A baseline refreshed to make a red run green
defeats the entire gate. The same goes for `allow/`: an entry needs a written reason above its block, and
the `anon_founder` and `public_execute` lists are ratchets — they may shrink, never grow.

## Not built yet

- pgTAP behavioural RLS tests (three seeded users: hospital, engineer, founder; cross-hospital isolation
  on `repair_jobs`/bids/escrow, `founder_*` refusing non-founders, `delete_my_account`/`export_my_data`
  scoped to the caller). These need a local stack to seed users into, so they are blocked on Docker.
- A `plpgsql_check` sweep over every plpgsql function with an allowlist of the ~15 known-accounted
  findings. `plpgsql_check` is available on the project but not installed; installing an extension is a
  founder decision.
- Deno tests for the edge functions: HMAC accept/reject for `razorpay-webhook` and `payouts-webhook`, the
  `X-Cron-Secret` 401 for `cron-tick`, malformed-token rejection for `verify-play-integrity`. Blocked on
  Deno, which is not installed here; the CI runner has it.
