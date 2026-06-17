-- Round 856 — Defensively add engineer_payouts.amount_rupees as a
-- STORED GENERATED column so r489 (three-way reconciliation) +
-- r490 (TDS 194O automation) stop silently failing if the column
-- was never actually present.
--
-- Background — discovered during r847 audit pass:
--
-- r422 (engineer_payouts schema) only defined amount_paise bigint.
-- r489 + r490 + r499 reference ep.amount_rupees with no preceding
-- ALTER TABLE … ADD COLUMN amount_rupees anywhere in the migration
-- history. Two possibilities:
--   1. Someone added the column via Supabase dashboard SQL outside
--      the migration history. Then r489/r490 work today.
--   2. The column was never added. Then r489 (run_daily_reconciliation
--      cron) and r490 (compute_tds_194o trigger on payout insert)
--      have been silently throwing on every fire — three-way recon
--      log empty, TDS deduction rows never written.
--
-- We can't tell from migration files alone. ADD COLUMN IF NOT EXISTS
-- is the safe move:
--   * If amount_rupees already exists (case 1) — no-op, no behavior change.
--   * If it doesn't exist (case 2) — it gets created as a GENERATED
--     column that always equals round(amount_paise/100, 2), which
--     matches the semantics every caller expects.
--
-- The expression is round(amount_paise::numeric / 100.0, 2). Both
-- operations are IMMUTABLE under PostgreSQL — required for a STORED
-- generated column.
--
-- We use STORED (not VIRTUAL — VIRTUAL is unsupported in PG as of 17)
-- so existing indexes / RLS filters that reference amount_rupees keep
-- working without a query rewrite.

BEGIN;

ALTER TABLE public.engineer_payouts
  ADD COLUMN IF NOT EXISTS amount_rupees numeric(12,2)
    GENERATED ALWAYS AS (round(amount_paise::numeric / 100.0, 2)) STORED;

COMMIT;
