# Independent QA — S3a SQL verification candidate

**Date:** 2026-09-27  
**Code reviewed:** `e58b7640bef2b009f870912d233de351a4dffbd0..9f501ce27f5e57642bb1043c1fb02fe8fe3213d9` on `codex/s3a-sql-verification-20260927`  
**Scope:** the disposable PGlite grant proof, its fixture and locked GitHub workflow. The round3828 production migration is unchanged and was not independently accepted in this review.  
**Score:** **9.6/10 for this verification-only scope.** No unresolved mandatory code defect found. This score is a review of the candidate, not main integration, hosted validation, production deployment or acceptance of the underlying S3a migration.

## Findings

- The test now executes the real round471 and round472 migrations in both disposable databases. The round472 telemetry control checks denial for both `anon` and `authenticated`, confirms no row was inserted after round3828, and separately checks that `service_role` still inserts a real row with the expected outcome and error code.
- The final `9f501ce2` change closes a legacy proof gap in the earlier `513c7a8b` revision: grouped controls now exercise both client roles across telemetry and all six stand-ins before asserting outcomes. The canary counts all rows because `current_user` inside a `SECURITY DEFINER` stand-in is the function owner. A separate precondition checks all 27 combinations of nine function signatures and three roles on the legacy database, so an early failure cannot hide later missing grants.
- The workflow covers changes to the test directory, both imported defining migrations, the round3828 migration and the workflow itself. It runs the test on relevant pull requests and candidate/main pushes using Node 24, a frozen pnpm lockfile and PGlite 0.5.8. It has read-only repository permission and uses synthetic local data.

## Evidence and limits

I independently ran `pnpm run test:s3a` on the **prior code revision `513c7a8b`**: exit 0, corrected properties **11/11**, expected legacy control failures **6/6**, and legacy legitimate paths **4/4**. I inspected the final `9f501ce2` diff but did not rerun it after the shared local build slot was released. The implementation agent reported its final local run exited 0 with corrected properties **11/11**, legacy grant preconditions **27/27**, expected legacy control failures **6/6**, and legacy legitimate paths **4/4**. Hosted CI on the pushed final code remains pending.

Only three of the nine money RPCs use real defining migrations in this fixture; six are signature-exact grant stand-ins. This review does not establish the behavior of those six production bodies, hosted Supabase privileges, provider behavior, deployment safety or production state. The underlying S3a round3828 migration remains a separate WIP requiring its own scoped tests, independent critic and QA, applicable hosted checks and integration decision.

During review, a disposable probe of **round472 alone** showed its historical `founder_payment_verify_failures` definition could return a synthetic event to a nonfounder. Repository migration round481 replaces that definition with an in-body `is_founder()` / `42501` gate, and round848 restores authenticated `EXECUTE` while retaining the gate. This is a historical round472 observation, not a current vulnerability finding or a defect introduced by this verification candidate.
