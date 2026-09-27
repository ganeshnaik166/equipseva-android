# Handoff — production-applied migration-history source sync, 27 September 2026

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

Get independent critic and QA reviews of the exact import, source provenance, and the boundary above. Then push this branch and open a separate PR for hosted checks and review; reconcile main only after those gates pass. Keep round3821/3823/3826/3827/3828 out of this import and handle round3828 S3a separately. No PR, hosted result, main merge, SQL execution or release acceptance is claimed here.
