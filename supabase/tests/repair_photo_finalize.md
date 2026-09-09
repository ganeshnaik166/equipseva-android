# Atomic repair-photo finalizer tests

`20263900000000_round3823_finalize_repair_photo.sql` adds an authenticated-engineer-only RPC. It validates canonical assignment, owned object path and size, takes the job's UPDATE lock before mapping/object SHARE locks, appends to the matching before/after array, and calls `register_evidence` in the same transaction. A successful result has one row: `ledger_id uuid, attachment_path text`. The path is the canonical bucket-relative object name stored in the array; the ledger URL also includes `repair-photos/`.

Registration failure rolls back the append. Repeating a valid request returns the original evidence ID without replacing its metadata. Attachment removal alone may be repaired by a still-authorized engineer; assignment/mapping/object revocation still blocks an existing-ID return. The digest and capture time remain client assertions. No job status or payment transition is performed.

Installation requires the exact reviewed registration contract, including normalized r3821 body fingerprint, owner matching the migration executor, signature, return type, language, definer/search-path/volatility and allowed effective/explicit grants. Missing, older or drifted dependencies fail with SQLSTATE `55000`. Reapplication refuses an existing helper with drifted ownership or unexpected/grant-option ACLs. The postcondition checks the resulting helper contract. Execute through the intended migration owner and apply r3821 first; do not bypass guards by editing historical files. SQL role claims in these tests do not prove deployed readiness.

## Focused semantics

From `supabase/tests`, install the existing pinned dependencies with `npm ci --ignore-scripts`, then run:

```sh
node --test repair_photo_finalize.test.mjs
```

The suite executes the actual fixture, r492, r3821 and finalizer migration. Populated tests cover before/after append, NULL/empty arrays, typed responses, immutable retries, committed-result replay, assignment/object/claim denials, canonical path/hash/size validation, legacy ownership precedence, incompatible evidence collisions and a ledger trigger that proves the append was seen before its injected error rolls the transaction back. Installation/reapply tests compare complete function catalog and row state, including unknown ownership/grant rejection. These are selected-schema PGlite tests, not independent-session concurrency, real JWT/Storage HTTP or a complete migration replay.

## Native concurrency

Python 3.12 standard library and PostgreSQL 16+ binaries are required. This runner imports the unchanged `evidence_concurrency.py` cluster/session implementation, provisions a fresh synthetic loopback-only cluster, and accepts only binary and output-workspace paths:

```sh
python repair_photo_finalize_concurrency.py \
  --pg-bin "$(pg_config --bindir)" \
  --output-root /tmp/equipseva-finalizer-tests
```

On Windows, pass the PostgreSQL `bin` directory and a test-workspace directory using ordinary quoted paths. There is no production DSN/host, credential or existing-data argument. No existing snapshot/evidence cluster is reused.

The 27 native schedules cover distinct before/before, after/after and mixed appends; same-key commit/rollback/incompatible-object outcomes; canonical assignment clear/reassign, engineer mapping clear/rebind, object owner/size/deletion and before/after attachment removal in both material orders; old direct registration overlap in both lock orders; and the old writer's unattached-object refusal. Calls use separate PostgreSQL sessions. A transaction holds real locks until the controller observes the other backend waiting through `pg_blocking_pids`, active SQL and an ungranted lock. Every explicit transaction ending, complete final job/mapping/object/ledger state, typed response and unchanged source/function identity is checked. No automatic RPC retry or sleep-only race release is used.

Each run is `evidence-concurrency-<timestamp>-<random>` beneath the chosen output root. Intended report, synthetic SQL, session/server and cleanup logs are under its `evidence/` child; database files/configuration are in sibling `data/`. CI must upload only `evidence/*.json`, `evidence/*.log` and `evidence/*.sql`. Keep failed runs as evidence. The runner stops only owned processes and verifies the listener, session exits and postmaster PID-file removal.

## Limits and rollout requirements

The concurrency guarantee covers cooperating finalizer calls. Existing Android whole-array replacement can later overwrite a committed attachment and remains unmodified. Storage row locks do not make remote bytes immutable or ensure retained availability. Client-side durable delivery, preparation/upload reconciliation, Room migrations, cancellation, account-generation isolation and completion prerequisites are separate work.

Before rollout, verify the complete migration-built repair-job trigger/RLS/column-grant contract and real Auth/PostgREST/Storage upload/metadata/byte behavior in an isolated nonproduction environment. Check actual deployed versions and owner/grant compatibility; last-known production alignment is not installation authorization. These tests neither deploy the function nor qualify full REL-01, M1 or the app. Higher isolation, cross-job lock cycles and global deadlock freedom are not claimed.

Use one schema-changing executor for dependency inspection, migration apply,
function/ACL readback and PostgREST schema-cache validation. The migration guards
check the state they observe; they do not coordinate with a concurrent DBA or
another migration runner. Apply r3821 before r3823, confirm the typed RPC is
visible after the cache reload, and stop on any dependency or ownership drift.
