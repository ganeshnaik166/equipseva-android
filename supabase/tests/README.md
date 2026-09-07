# Focused backend regression tests

Run from this directory with Node.js 24:

```sh
npm ci --ignore-scripts
npm test
```

`npm test` runs the evidence SQL, cron handler and snapshot migration suites.
Run them separately with `npm run test:evidence`, `npm run test:cron` or
`npm run test:snapshot`.

The cron suite executes the real TypeScript handler with isolated SDK, Deno
serve, environment and fetch stubs. It verifies authorization, all slot
groups, sequential execution, safe error codes and both returned and thrown
run-history failures. It performs no real jobs or network requests. Node's VM
modules and TypeScript stripping do not replace the separate Deno import/type
check or deployed Edge integration.

From the repository root, `python3 scripts/test_cron_response_summary.py`
executes the actual daily response-summary CLI against synthetic responses.
It verifies response validation, private-field suppression, curl exit codes,
and separate reporting of missing/failed history persistence. The backend CI
workflow runs all these suites; changing a migration, cron handler, test or
summarizer triggers it.

## Snapshot migration coverage

`storage_snapshot_timeout.test.mjs` executes the complete historical round601
migration and the actual round3822 forward migration in disposable PGlite
databases. It checks apply/reapply, function-only reset rollback, unchanged
body/owner/ACL/search path and role/database settings, direct role denials,
authorized service execution, strict retention, relation selection, catalog
estimates and append semantics. No database URL or credential is read.

This small single-connection fixture does **not** establish an elapsed statement
deadline, PostgREST metadata hoisting, pool restoration, independent lock waits,
large-database capacity or deployed Supabase behavior. The separate native
PostgreSQL/PostgREST evidence and rollout gates are described in
[`STORAGE_SNAPSHOT_TIMEOUT_ROLLOUT.md`](../../docs/STORAGE_SNAPSHOT_TIMEOUT_ROLLOUT.md).

## Evidence SQL coverage

`package.json` pins `@electric-sql/pglite` to 0.5.8. If dependencies are already
provisioned elsewhere, set `EQS_PGLITE_PACKAGE` to that package directory before
running `node evidence_authorization.test.mjs`. No database URL or credential is
read. Each run creates and closes disposable in-memory PGlite databases.

The harness loads the exact round492 migration into a minimal populated schema
and demonstrates three original failures: fabricated-source registration,
outsider access to a no-bid job's evidence, and access to a deleted producer's
hash record. In a new database it applies the exact forward round3821 migration
and checks authorization, canonical AMC/reassignment handling, owned and attached
objects, malformed paths, idempotency, collision ownership, anonymous privileges
and the unchanged round3819 canonical writer. Fixture identities are synthetic.

These are real PostgreSQL function executions on a focused fixture. They are
**not** a replay of all project migrations or proof of effective production
policies, user-role triggers, Storage service behavior, on-device outbox behavior,
or legal evidence validity. Rapid duplicate submissions are queued on one
PGlite connection; an independent-session concurrency/lock test is still needed
against ordinary PostgreSQL. Registration holds SHARE locks on the job,
engineer row and object until commit, but this harness cannot prove all live
lock interactions or deployment-specific constraints.

## Integration and release checks still required

- Compare the deployed table/Storage schema, function definitions, ownership and
  ACLs against this migration in an authorized read-only inspection.
- Run populated multi-role integration tests on a complete migration-built
  Supabase test project, including real Storage upload and signed download.
- Verify Android r3820 receipts have the exact uid/job/filename key, owner and
  Storage metadata size that the registration RPC now requires.
- Test delayed registration after assignment changes. Former engineers cannot
  register or read through the per-job reader after canonical reassignment;
  historical producer hash reads retain their original producer-only contract.
- A successful upload whose job attachment failed is now denied registration.
  This is deliberate authorization; durable attach/register reconciliation is
  separate REL-01 work and is not solved by this migration.
- The original ledger uniqueness key omits storage object identity. The same
  digest under a different object or producer returns a conflict instead of
  claiming or overwriting the original row. A future multi-object evidence
  model requires an explicit schema/contract change.
- Trusted service-role registration keeps its prior nonrepair/source-kind
  contract. Those internal producers must validate their own source authority;
  ordinary clients cannot request those kinds. GPS/signature internal writers
  remain separate and are not newly exposed.
- Existing possibly forged records are not rewritten or certified by this fix.
  Historical integrity reconciliation, stored-byte verification, evidence-object
  immutability and retention require separate authorized work.
- Canonical assignment is trusted here as in the existing attendance writer.
  Audit direct job INSERT and status-transition authority separately: a caller
  supplying engineer_id on a self-owned requested job may manufacture a
  preassignment. Merely filtering requested status would not prove a legitimate
  assignment, because later transition rules also matter. No source-creation
  provenance claim is made by this patch.

Deploy the forward migration only after integration/compatibility review. It
does not rewrite old migrations or mutate existing ledger data. Reapplying it
is tested; reverting to the old vulnerable functions is not an acceptable
security rollback. Use a reviewed forward correction or temporarily contain the
affected RPC while preserving uploaded files and queued-work recovery.
