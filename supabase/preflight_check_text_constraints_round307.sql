-- Pre-flight check before `supabase db push` of round-307 migrations.
--
-- The new CHECK constraints in 20260706000000_round307_spot_audit_feedback_cap.sql
-- validate every existing row at apply time (no NOT VALID).  Empty result set
-- means safe to push.
--
-- Run via Supabase SQL editor or psql:
--   psql "$SUPABASE_DB_URL" -f supabase/preflight_check_text_constraints_round307.sql

\echo '=== round 307 — spot_audit_responses.feedback > 500 ==='
SELECT 'spot_audit_responses.feedback > 500' AS rule, id, char_length(feedback) AS len
  FROM public.spot_audit_responses
 WHERE char_length(feedback) > 500
 LIMIT 5;

\echo '=== round 307 — amc_admin_escalations.notes > 1000 ==='
SELECT 'amc_admin_escalations.notes > 1000' AS rule, id, char_length(notes) AS len
  FROM public.amc_admin_escalations
 WHERE char_length(notes) > 1000
 LIMIT 5;

\echo '=== round 308 — FK index migration is index-only, no row validation needed ==='

\echo '=== pre-flight complete — empty result set = safe to db push ==='
