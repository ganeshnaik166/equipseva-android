# QA — main-based migration-history replay integration — 27 September 2026

Reviewed frozen source `8e91e2010538ee8c3674511f1e6f247c37b3630b` on `codex/migration-history-replay-integration-20260927`.

**9.6/10 for the bounded source/workflow port; no mandatory source blocker.** QA checked exact parity of six imported SQL/test files with `a1d67a07`, independently reproduced original unseeded round3825's `23503` foreign-key failure, and ran the repaired PGlite suite **3/3**. Locked offline pnpm install, Node syntax check, official actionlint v1.7.12 and diff check exited 0.

The workflow includes both migration filenames and the predecessor/test/workflow paths, uses `contents: read`, does not persist checkout credentials, and holds no secrets. The in-memory fixture verifies round3825's absent founder, case-variant email, seeded audit and non-founder behavior. It does not execute round3824 or a clean Supabase reset; hosted exact-head checks and full replay remain mandatory before main integration. Deployed SQL-byte parity remains indeterminate.
