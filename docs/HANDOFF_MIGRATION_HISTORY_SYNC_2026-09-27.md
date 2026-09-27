# Handoff — production-applied migration-history source sync, 27 September 2026

## Current WIP repair checkpoint

The isolated repair code is `cfdef45130dbefa7e242408cc5321d451f3b65f4` on `codex/migration-history-sync-20260927`. It leaves round3824 at source blob `a9777e2dd998815f15b98882d1a284d6c0dc9c4f`. Round3825 is now blob `43352752f21e0fcf04b3841440f78c4e11602e51`, deliberately different from imported source blob `106636cbc98fa1b76dbb25ce14f944b9f3ba618c`. The only SQL behavior change is a guard on the data-dependent GREEN probe: it runs when the exact claimed founder id and stored email both exist in `auth.users`; otherwise it reports a skip. The cast-free function-body and no-leaked-audit-row checks still run. Comparison of the two Git versions confirms the entire `CREATE OR REPLACE FUNCTION public.founder_audit_table_mutation()` block is text-identical. No function/grant/table/trigger DDL, app code or round3824 SQL changed. No SQL was sent to production, and production SQL-byte parity remains indeterminate.

The new `supabase/replay-tests/` package pins PGlite 0.5.8 and uses an in-memory predecessor fixture with the exact pre-change trigger function, seven enabled triggers, and the audit foreign key. Before changing round3825, `pnpm test` against the original imported file exited 1: **1/2 passed**, and the unseeded case failed at the GREEN update with foreign-key SQLSTATE `23503`; the seeded case passed. On repaired code `cfdef451`, `pnpm test` exited 0: **3/3 passed** for absent founder, same-id case-variant email, and matching founder plus non-founder early return. The tests assert the migration commits, the new function is cast-free, the temporary probe and audit row do not remain, and a separate rollback-scoped founder write records the right audit actor, target, operation and before/after values. These are focused local tests, **not** a full clean Supabase replay or hosted CI.

Independent [critic](helper-reviews/codex-20260927/migration-history-replay-critic.md) and [QA](helper-reviews/codex-20260927/migration-history-replay-qa.md) of corrected code `cfdef451` each scored **9.6/10** for the focused SQL/fixture scope, with no remaining source blocker. The earlier 9.3/9.3 scores below apply only to the exact imported blobs. A full disposable Supabase reset is still required: neither Supabase CLI nor Docker was available on this host's PATH, and the PGlite fixture does not replay the earlier migration history. Hosted checks remain pending; the ordinary Android workflow does not run this new SQL suite. Keep this WIP out of main until full replay and relevant hosted checks pass. Do not turn source-blob provenance or migration-version presence into a claim of deployed SQL-byte parity. Round3821/3823/3826/3827/3828 remain outside this repair; no PR, main merge, deployment or release acceptance is claimed.

## Scope and source

Branch `codex/migration-history-sync-20260927` began at fetched `origin/main` `b5679244370a7a8470744bd3aa12568e57179727`. Code commit `1d2e4251` restores exactly two files from `origin/backend/regression-suite` (`638cc3d6ec3cbf0ea04ad5b712fabd4755987b49`):

| Migration | Git blob in source and restored checkout | Purpose recorded by the source author |
|---|---|---|
| `supabase/migrations/20263901000000_round3824_founder_console_execute_grants.sql` | `a9777e2dd998815f15b98882d1a284d6c0dc9c4f` | Grant founder-console RPC execution to the authenticated caller behind checked gates, gate the previously ungated dead-letter summary, and revoke public/client execution of the snapshot writer. |
| `supabase/migrations/20263902000000_round3825_founder_audit_trigger_row_cast.sql` | `106636cbc98fa1b76dbb25ce14f944b9f3ba618c` | Replace invalid trigger-row `::jsonb` casts with `to_jsonb(...)` in the founder audit function. |

The files were imported with `git restore --source=origin/backend/regression-suite` and left byte-for-byte unchanged. No other source-branch file or commit was imported. This is a repository history repair before the separate round3828 S3a grant rollout, not a migration execution.

## Evidence boundary

The coordinator's dedicated read-only production migration-history endpoint reported versions `20263901000000` and `20263902000000` applied, and round3821/3823/3826/3827/3828 absent. **Production SQL-byte parity is indeterminate:** the API returns split statements, not the original migration file bytes. Version presence therefore does not prove exact deployed bytes or current runtime behavior.

The earlier source author's `docs/HANDOFF_2026-09-18_BACKEND_SUITE.md` on `origin/backend/regression-suite` records round3824 transaction rollback, negative controls, pre-change ACL capture, application and post-apply observations. It also records round3825 RED/GREEN temp-table trigger probes, negative controls and post-conditions. Those are **prior author evidence**, not probes rerun by this branch. No SQL, DB, Gradle, app tests or production mutation ran during this restoration.

Local verification: `git ls-tree` source blob IDs equaled `git hash-object` and the staged index blob IDs for both restored files; `git diff --cached --check` exited 0 before the code commit. The code commit changes only those two files (636 added lines). The continuity documents record the scope and unresolved gates.

## Next review and integration

Independent exact-import critic **9.3/10** and QA **9.3/10** both **block main integration**. The round3825 green probe uses a fixed founder identity while its audit row references `auth.users`; no tracked seed creates that user, so a clean or preview replay may fail the foreign key and roll back the migration. The source author did not prove clean replay. Existing main files already contain the same founder identifiers, but do not repeat them in new documentation. This exact-file branch is a WIP provenance record, not a generally replay-safe history repair. Establish a disposable clean replay or an environment-independent reconciliation before main/preview integration. Keep round3821/3823/3826/3827/3828 out of this import and handle round3828 S3a separately. No PR, hosted result, main merge, SQL execution or release acceptance is claimed here.
