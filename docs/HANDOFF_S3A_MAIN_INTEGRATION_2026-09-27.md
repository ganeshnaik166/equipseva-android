# S3a service-only money-RPC grants — main-based WIP, 27 September 2026

## Resume point

Branch `codex/money-rpc-grants-20260927` in the isolated `work/equipseva-money-rpc-grants-20260927` checkout starts from fetched `origin/main` **`b5679244370a7a8470744bd3aa12568e57179727`**. Frozen source/test commit **`bf3ff771eec790f17f6797f25c568918f2acd762`** is a selective port of Claude's S3a grant fix. It is local WIP: no PR, main merge, live catalog query or production migration is claimed. The shared build slot was released at **10:45 UTC**.

The only migration is `supabase/migrations/20263905000000_round3828_service_only_money_rpc_grants.sql`. Its Git blob **`d743327c2a23f1d35cc031e5bf06c604bce2037f`** matches `origin/codex/s3a-sql-verification-20260927` exactly. It revokes direct and PUBLIC `EXECUTE` from `anon`/`authenticated` on nine payment-capture, refund, AMC-credit, payment-telemetry, engineer-payout and escrow-worker functions, retains `service_role`, and aborts if its final catalog checks fail. The port also adds `.github/workflows/supabase-sql-s3a.yml`, `supabase/tests/package.json`, `pnpm-lock.yaml`, the PGlite test and two **synthetic** fixtures, plus a `.gitignore` entry. No round3826/3827 migration, Android source or unrelated Claude branch history was imported.

## Exact-port local verification

From `supabase/tests`, `pnpm install --frozen-lockfile` using pnpm **11.25.0**, `node --check service_only_money_rpc_grants.test.mjs` and `node service_only_money_rpc_grants.test.mjs` exited **0**. The offline PGlite test reports **11/11 new-state properties pass**, **27/27 legacy grant preconditions**, **6/6 negative controls fail on legacy as expected**, and **4/4 legitimate service-role/owner-run paths pass**. Those `FAIL legacy` labels are expected controls; the overall test command passed. Logs are outside Git in `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/` as `s3a-main-install-20260927.log` and `s3a-main-test-20260927.log`.

The first selective-port run stopped only because `engineer_location_privacy.fixture.sql` was missing. Copying that **synthetic base fixture**, without the S1 migration, made the rerun green. The harness applies real round471/472 payment migrations and signature-exact stand-ins for six other functions in disposable PGlite databases. It proves the named grant behavior under those fixtures; it does not prove the current hosted catalog, every function body, real provider events, or deployment order.

## Review and remaining gates

Independent critic and QA each scored the frozen **main-based `bf3ff771` source/test candidate 9.6/10**, with no mandatory code blocker for the bounded S3a scope. The critic independently reran PGlite with exit 0 and confirmed no blocked S1/S2 migration was ported. Hosted CI for this exact branch/PR and a read-only **current deployed catalog** preflight of all nine signatures, grants, callers and migration ordering remain open. The historical production snapshot referenced in the migration is not a current live query. No production change was made here. The new workflow is present, but its hosted run on this exact port has not been observed. If round3828 is applied before corrected S1/S2, those fixes need new forward migration versions or a separately tested migration-history procedure.

Future functions may inherit permissive default `EXECUTE` privileges; round3828 only closes the nine enumerated current signatures. A separate reviewed default-privilege policy remains open. S1 round3826 remains blocked on raw-address leakage (critic **8.2**, QA **7.8**); S2 round3827 remains blocked on exact-distance leakage (critic **7.8**, QA **8.2**). Neither belongs in this S3a integration, despite related location fixtures.

Next: fetch the branch, confirm the SQL blob and eight-file scope, observe exact-branch hosted checks, then inspect the current deployed catalog and migration order before proposing main integration or a separately controlled production rollout. Preserve other worktrees; do not treat local PGlite, previous-branch CI or the bounded scores as deployment acceptance.
