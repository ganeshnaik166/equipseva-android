# QA — round3825 focused replay repair — 27 September 2026

Reviewed frozen code `cfdef45130dbefa7e242408cc5321d451f3b65f4` on `codex/migration-history-sync-20260927`.

**9.6/10 for the bounded SQL/fixture repair; no remaining source blocker.** QA independently ran the PGlite suite **3/3** and checked the original unseeded file's foreign-key failure (`23503`) in disposable memory. The repaired unseeded and case-variant cases commit without a probe audit row; the matching-founder path proves a runtime audit row, non-founder early return and rollback cleanup. `git diff --check` passed.

The seven-trigger predecessor fixture is focused and does not execute the full migration chain. A full clean Supabase replay and a hosted SQL check are required before main integration; the ordinary Android workflow does not run this suite. Production SQL-byte parity remains indeterminate.
