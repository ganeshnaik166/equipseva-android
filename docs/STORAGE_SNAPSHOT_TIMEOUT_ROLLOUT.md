# Storage snapshot timeout candidate

This is a local implementation and rollout guide. Production recovery is not
confirmed. Do not execute deployment steps until the prerequisites below have
evidence and the intended environment has been checked.

## Scope and rationale

Round3822 changes only the function setting on
`public.db_storage_snapshot_sweep()` to a finite `statement_timeout = '30s'`.
It preserves the round601 writer, signature, owner, access grants, fixed search
path, ledger/indexes, ninety-day retention and scheduling. It does not call the
writer, change any role/database/global timeout, increase the lock limit or
introduce retries. A successful writer call still appends a new full batch.

The historical September 7 daily failure recorded SQLSTATE `57014` and an
8,409 ms snapshot call. The writer matched round601 and the REST connection
role had eight-second statement and lock limits. This supports a timeout
diagnosis but does not prove the exact historical cancellation trigger.

An isolated PostgreSQL 17.11/PostgREST 16.2 fixture with 4,876 regular public
tables reproduced eight-second cancellation. With correctly cached function
settings, three natural calls completed in 16.766, 13.969 and 14.203 seconds.
Thirty seconds leaves 13.234 seconds above the slowest observed call. These are
synthetic samples with warm filesystem history, not a production percentile
or cold-cache capacity estimate. The setting permits more execution time; it
does not optimize the query or solve persistent lock contention.

Thirty seconds bounds the **whole statement**, including work and lock waits;
it is not an additional thirty seconds after waiting for a lock. The separate
eight-second lock bound remains in effect for each lock acquisition. The other
25 sequential daily slots and network/Edge overhead must still fit the daily
workflow's existing 120-second HTTP limit with justified headroom.

## Source and local verification

The forward file is
[`20263899000000_round3822_storage_snapshot_timeout.sql`](../supabase/migrations/20263899000000_round3822_storage_snapshot_timeout.sql).
It is designed to fail when the writer contract or accepted prior settings
have drifted. Investigate drift instead of removing a failing precondition.
Idempotent migration reapplication does not make writer invocations idempotent.

The CI suite executes actual round601 and round3822 SQL on a small disposable
PGlite database. It verifies catalog/data/access invariants and reapplication;
it supplies no elapsed-time, REST-cache or multi-connection capacity proof.

Separate saved native experiments establish above-eight-second REST success,
finite cancellation after insertion and pruning with transaction rollback,
controlled late-error rollback, eight-second independent lock waiting,
post-lock writer recovery and distinct complete appended batches. An early
failed cache-readiness experiment is retained: a healthy root endpoint plus a
short sleep did not establish fresh routine metadata. Actual final migration
replay and final role checks must be bound to the final file hash before the
local candidate is accepted.

## Staging and deployment prerequisites

Use one schema-change executor for both rollout and rollback. Exclude concurrent
admin, CLI and migration changes throughout preflight, application, metadata
readback and cache verification; recheck the prior state after establishing that
exclusivity. The SQL guards detect observed drift and do not coordinate concurrent
writers. If exclusive schema-change execution cannot be established, do not apply.

1. Fetch the intended source and record its commit and migration hash. Compare
   the selected database's routine signature/body, owner, effective EXECUTE
   grants and only allowlisted configuration fields against the reviewed
   source. Record prior function settings and role/database statement and lock
   limits. Do not dump connection strings, JWT secrets or whole service configs.
2. Verify the serving PostgREST version and that its function-setting hoisting
   configuration permits `statement_timeout`. A SQL catalog value alone is not
   evidence of the effective REST deadline. PostgreSQL direct calls and REST
   calls have different statement-start behavior.
3. In isolated staging, apply the exact migration and verify **serving cache**
   readiness before a targeted writer test. The migration's transactional
   `NOTIFY pgrst, 'reload schema'` requests refresh; delivery is not confirmation.
   Inspect the relevant cached routine setting through a safely filtered admin
   schema-cache view when supported, or use a verified new read-only cache marker
   committed with the test change. Starting an isolated server after committing
   the setting is another local option. HTTP 200 from `/`, a config readback or
   an arbitrary sleep is insufficient. Remove synthetic marker functions after
   the staging test and refresh cache again.
4. Run final service/anonymous/authenticated access, effective finite deadline,
   lock bound, rollback and recovery cases through the actual staging REST path.
   Evaluate representative load and the complete daily request budget without
   touching real billing, notifications or retention data. Recorded mocks can
   verify control flow but cannot establish production capacity.
5. Review the database migration and Edge/workflow rollout as separate changes.
   Inspect the pending migration queue too: this branch also contains round3821
   evidence authorization with separate integration gates. A bulk database push
   must not silently deploy that unfinished candidate. Local round3822 acceptance
   does not accept earlier pending migrations or the full migration chain.
   Applying SQL does not deploy the reporting handler. Check hosting-specific
   execution limits, source deployment triggers and the next scheduled window.
   Keep the existing limit if the evidence is insufficient; do not widen it
   again or replay the full daily group to obtain a green run.

PostgREST documents hoisted settings and their transaction scope; Supabase
documents function-level timeouts for REST callers. Verify the deployed setup
instead of assuming it matches the local runtime.
[PostgREST transaction settings](https://postgrest.org/en/stable/references/transactions.html),
[Supabase timeouts](https://supabase.com/docs/guides/database/postgres/timeouts).

## Function-only rollback

For the recorded original state, the function has a fixed search path and **no**
function-local statement timeout. A reviewed compensating migration can restore
that state with:

```sql
BEGIN;
ALTER FUNCTION public.db_storage_snapshot_sweep() RESET statement_timeout;
NOTIFY pgrst, 'reload schema';
COMMIT;
```

Use this exact reset only when the recorded prior state had no function timeout
and current metadata still matches the reviewed candidate. If a different prior
setting was deliberately accepted, restore that specific captured value instead.
Never use `RESET ALL`: it would also remove the function's fixed search path.
Recheck body, owner, ACLs, remaining function settings and unchanged role/database
limits, then verify serving-cache refresh using the same readiness standard.
[PostgreSQL ALTER FUNCTION](https://www.postgresql.org/docs/current/sql-alterfunction.html).

Rollback does not cancel already-running requests, reverse committed batches or
rewrite migration history. Existing requests may retain the previous cache or
transaction setting. A timed-out client response does not prove the operation
rolled back; inspect outcome metadata before deciding a separately authorized
next action. Do not delete committed history to simulate rollback.

## Recovery acceptance

After the reviewed rollout, inspect the next natural scheduled run and safe
history metadata. Require successful job outcomes, confirmed run-history
persistence, a fresh complete snapshot batch and acceptable total duration.
An absent history row, old handler's unreported persistence, HTTP 200 alone or
an isolated direct SQL success is insufficient. Do not manually replay `daily`:
it includes money reconciliation, notifications, purges and append-only work.

Until deployed compatibility, complete request headroom and natural scheduled
recovery are evidenced, broader cron reliability and M1 remain unaccepted.
