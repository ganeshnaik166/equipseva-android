# Backend regression suite (work in progress)

Purpose: give the SQL/RLS/grant surface the same kind of gate the UI got from screenshot tests. The
recurring defect classes this is meant to catch, each of which has bitten production at least once:

* a `SECURITY DEFINER` RPC shipped without `GRANT EXECUTE TO authenticated`, so every real caller gets a
  silent 42501 while the migration run stays green;
* Supabase's default privileges publishing `EXECUTE` on a freshly created function to `anon`;
* latent plpgsql errors (wrong column names, unordered result sets) that only a `plpgsql_check` sweep finds;
* maintenance functions that exceed the REST role budget (`authenticator` runs `statement_timeout=8s`
  against 4,876 public tables);
* tables without RLS, or policies that leak rows across hospital/engineer/founder;
* edge functions with no tests at all — HMAC verification in the webhooks, the `X-Cron-Secret` gate,
  Play Integrity token handling.

## What exists today

`snapshot/` — the truth snapshot, as committed data:

| file | one row per |
|---|---|
| `functions.sql` | function overload: signature, language, kind, secdef, volatility, owner, `proconfig`, PUBLIC/anon/authenticated/service_role EXECUTE, body md5 |
| `tables.sql` | ordinary table: `rowsecurity`, `forcerowsecurity`, owner, policy count, per-role table privileges |
| `policies.sql` | policy: command, permissive, roles, normalised USING and WITH CHECK text |
| `run.mjs` | runs each `.sql` through the Supabase CLI and writes sorted TSV into `baseline/` (`--target local\|prod`, `--out <dir>`) |
| `scan_rpc_callsites.mjs` | every `.rpc("name")` call site in `app/src/main`, `web/src` and `supabase/functions` with the role that client runs as, as TSV |

TSV with one object per sorted line is deliberate: at ~19k functions and ~3.5k policies, a JSON dump is
unreviewable, while `git diff` over sorted lines reads as "which object changed".

## Blocked, and why

Phase 0 (a local stack: `supabase start` + `supabase db reset` replaying ~3,376 migrations) **cannot run on
this machine**: there is no `docker`, `gh`, `node`, `deno` or `psql` on PATH, and no Docker daemon. Verified
2026-09-16. Consequences:

* the snapshot runner has only ever been exercised in the `--target prod` direction (read-only
  `supabase db query --linked`), and its local path is unverified;
* `baseline/` is intentionally empty — a baseline captured from prod alone would pin prod's drift as the
  expected state, and the local-vs-prod diff (the part that finds real findings) has no local side to diff
  against;
* the pgTAP behavioural RLS tests and the Deno edge-function tests cannot be written against a stack that
  cannot be started.

Node is reachable indirectly (`ELECTRON_RUN_AS_NODE=1 "<VS Code>/Code.exe" script.mjs` gives Node 24), which
is why the runners are `.mjs`. The Supabase CLI lives at `C:/Users/lokes/supabase-cli/supabase.exe`.

To unblock: install Docker Desktop (or run the suite in CI, where `supabase/setup-cli` + a Postgres service
are available) and Node LTS, then capture `baseline/` from a freshly reset local stack in the same commit
that starts enforcing it.

## Refresh rule

A file under `baseline/` changes **only** in the commit that intentionally changes the schema, and that
commit's message must say which objects moved and why. A baseline updated "to make the suite pass" defeats
the whole point.
