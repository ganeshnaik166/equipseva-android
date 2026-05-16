-- Pre-flight check before running `supabase db push` of the round
-- 281-292 migrations.
--
-- All CHECK constraints in those migrations are added without
-- `NOT VALID`, so Postgres validates every existing row at apply
-- time. If even one row violates the new bound, the ALTER fails and
-- the migration aborts. This script lists any rows that would block
-- a clean apply — empty result set means safe to push.
--
-- Run via Supabase SQL editor or psql:
--   psql "$SUPABASE_DB_URL" -f supabase/preflight_check_text_constraints_round281_292.sql
--
-- If anything turns up, options:
--   (a) UPDATE the offending row(s) to fit (truncate / null out).
--   (b) Edit the migration to use NOT VALID, then run
--       VALIDATE CONSTRAINT later after data is cleaned.

\echo '=== round 281 — user_addresses caps ==='
SELECT 'user_addresses.label > 80'      AS rule, id, char_length(label)     AS len FROM public.user_addresses WHERE char_length(label)     > 80    LIMIT 5;
SELECT 'user_addresses.full_name > 200' AS rule, id, char_length(full_name) AS len FROM public.user_addresses WHERE char_length(full_name) > 200   LIMIT 5;
SELECT 'user_addresses.line1 > 200'     AS rule, id, char_length(line1)     AS len FROM public.user_addresses WHERE char_length(line1)     > 200   LIMIT 5;
SELECT 'user_addresses.line2 > 200'     AS rule, id, char_length(line2)     AS len FROM public.user_addresses WHERE char_length(line2)     > 200   LIMIT 5;
SELECT 'user_addresses.landmark > 200'  AS rule, id, char_length(landmark)  AS len FROM public.user_addresses WHERE char_length(landmark)  > 200   LIMIT 5;
SELECT 'user_addresses.city > 120'      AS rule, id, char_length(city)      AS len FROM public.user_addresses WHERE char_length(city)      > 120   LIMIT 5;
SELECT 'user_addresses.state > 80'      AS rule, id, char_length(state)     AS len FROM public.user_addresses WHERE char_length(state)     > 80    LIMIT 5;

\echo '=== round 283 — amc_contracts.scope_text > 4000 ==='
SELECT 'amc_contracts.scope_text > 4000' AS rule, id, char_length(scope_text) AS len FROM public.amc_contracts WHERE char_length(scope_text) > 4000 LIMIT 5;

\echo '=== round 284 — engineers.bio > 1500 ==='
SELECT 'engineers.bio > 1500' AS rule, id, char_length(bio) AS len FROM public.engineers WHERE char_length(bio) > 1500 LIMIT 5;

\echo '=== round 286 — chat_messages.message > 4000 ==='
SELECT 'chat_messages.message > 4000' AS rule, id, char_length(message) AS len FROM public.chat_messages WHERE char_length(message) > 4000 LIMIT 5;

\echo '=== round 289 — profiles.full_name > 200 / phone > 20 ==='
SELECT 'profiles.full_name > 200' AS rule, id, char_length(full_name) AS len FROM public.profiles WHERE char_length(full_name) > 200 LIMIT 5;
SELECT 'profiles.phone > 20'      AS rule, id, char_length(phone)     AS len FROM public.profiles WHERE char_length(phone)     > 20  LIMIT 5;

\echo '=== round 290 — open escrow with NULL user_id (should be impossible since columns were NOT NULL) ==='
SELECT 'open escrow NULL hospital_user_id' AS rule, id, status FROM public.repair_job_escrow
 WHERE status IN ('pending','held','in_dispute') AND hospital_user_id IS NULL LIMIT 5;
SELECT 'open escrow NULL engineer_user_id' AS rule, id, status FROM public.repair_job_escrow
 WHERE status IN ('pending','held','in_dispute') AND engineer_user_id IS NULL LIMIT 5;

\echo '=== pre-flight complete — empty result set = safe to db push ==='
