# Independent critic — S3a SQL verification candidate

**Date:** 27 September 2026  
**Frozen code head:** `9f501ce27f5e57642bb1043c1fb02fe8fe3213d9`  
**Base:** `e58b7640bef2b009f870912d233de351a4dffbd0`  
**Score:** **9.6/10 for this verification-only scope.** No unresolved mandatory code finding.

## Scope and result

I reviewed the disposable round3828 PGlite test and fixture, the new locked `supabase/tests` package, and the dedicated Node 24 GitHub workflow. The candidate loads the real round471 and round472 migrations for three of the nine protected RPCs. It checks that both client roles lose access after round3828, while service-role paths still work. The other six RPCs remain signature-exact stand-ins, and the handoff identifies this limit accurately. The production round3828 migration is unchanged by this branch.

## Finding and resolution

On the earlier `513c7a8b` code head, I scored **9.2/10 with one mandatory finding**: legacy control properties stopped at the first successful forged call. The new telemetry control never reached `authenticated` on legacy, and the nine-function catalog control stopped at its first failing signature. A passing summary therefore did not prove all legacy role/function grant preconditions.

Commit `9f501ce2` resolves that finding. Before running the properties, the test now asserts all **27** legacy grant preconditions: `anon`, `authenticated`, and `service_role` for each of the nine RPC signatures. Its telemetry and six stand-in controls exercise both client roles before comparing outcomes. On the corrected database, they require `42501` for every call and no telemetry or canary writes. The pre-existing real webhook controls, service-role regressions, and twice-applied round3828 check remain in place. I found no further mandatory defect in the declared verification scope.

## Evidence and boundaries

I inspected the exact source diff, the real round471/round472/round3828 SQL, fixture dependencies, workflow, and repository acceptance instructions. The implementation agent reports `pnpm install --frozen-lockfile` exit 0 and a local rerun on `9f501ce2` with **11/11 corrected properties**, **27/27 legacy grant preconditions**, **6/6 legacy controls failing as expected**, and **4/4 legitimate legacy paths passing**. I did **not** independently rerun the test or use production services.

Hosted CI on the final head and separate QA review are still pending. This score covers the quality of the verification candidate only. It does not accept the underlying S3a money-RPC migration, prove the six stand-in function bodies, establish deployed Supabase grants, or approve integration or release. Those decisions require their own scoped evidence and reviews.
