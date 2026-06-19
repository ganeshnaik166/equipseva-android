BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_attempts_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_attempts_summary()
RETURNS TABLE (
  metric        text,
  value_text    text,
  value_num     numeric,
  bucket        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH
  all_a AS (
    SELECT * FROM public.amc_renewal_attempts
  ),
  win_30 AS (
    SELECT * FROM public.amc_renewal_attempts
    WHERE attempted_at >= now() - interval '30 days'
  ),
  win_7 AS (
    SELECT * FROM public.amc_renewal_attempts
    WHERE attempted_at >= now() - interval '7 days'
  ),
  win_24 AS (
    SELECT * FROM public.amc_renewal_attempts
    WHERE attempted_at >= now() - interval '24 hours'
  ),
  exhausted AS (
    -- Contracts with >=3 failed attempts (cron threshold for renewal_failed flip)
    SELECT amc_contract_id
    FROM public.amc_renewal_attempts
    WHERE status = 'failed'
    GROUP BY amc_contract_id
    HAVING count(*) >= 3
  ),
  pending_stuck AS (
    -- Pending attempts older than 24h = stuck (worker should have resolved)
    SELECT * FROM public.amc_renewal_attempts
    WHERE status = 'pending'
      AND attempted_at < now() - interval '24 hours'
  ),
  latest_attempt AS (
    SELECT max(attempted_at) AS ts FROM public.amc_renewal_attempts
  ),
  last_succ AS (
    SELECT max(resolved_at) AS ts FROM public.amc_renewal_attempts WHERE status = 'succeeded'
  ),
  last_fail AS (
    SELECT max(resolved_at) AS ts FROM public.amc_renewal_attempts WHERE status = 'failed'
  )
  SELECT * FROM (VALUES
    ('Total attempts (all-time)',
       to_char((SELECT count(*) FROM all_a), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_a),
       'volume'),

    ('Attempts (last 30d)',
       to_char((SELECT count(*) FROM win_30), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30),
       'volume'),

    ('Attempts (last 7d)',
       to_char((SELECT count(*) FROM win_7), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_7),
       'volume'),

    ('Attempts (last 24h)',
       to_char((SELECT count(*) FROM win_24), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_24),
       'volume'),

    ('Succeeded (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='succeeded'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded'),
       'outcome'),

    ('Failed (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='failed'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='failed'),
       'outcome'),

    ('Abandoned (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='abandoned'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='abandoned'),
       'outcome'),

    ('Pending (open)',
       to_char((SELECT count(*) FROM all_a WHERE status='pending'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_a WHERE status='pending'),
       'outcome'),

    ('Success rate (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','abandoned')) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','abandoned')), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','abandoned')) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','abandoned')), 0),
            1)
       END,
       'rate'),

    ('Failure rate (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','abandoned')) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='failed')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','abandoned')), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','abandoned')) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='failed')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','abandoned')), 0),
            1)
       END,
       'rate'),

    ('Retry-exhausted contracts (>=3 fails)',
       to_char((SELECT count(*) FROM exhausted), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM exhausted),
       'risk'),

    ('Stuck pending (>24h)',
       to_char((SELECT count(*) FROM pending_stuck), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM pending_stuck),
       'risk'),

    ('Revenue succeeded (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(amount_rupees) FROM win_30 WHERE status='succeeded'),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(amount_rupees)::numeric FROM win_30 WHERE status='succeeded'),0),
       'money'),

    ('Revenue at-risk failed (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(amount_rupees) FROM win_30 WHERE status='failed'),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(amount_rupees)::numeric FROM win_30 WHERE status='failed'),0),
       'money'),

    ('Avg attempts per contract (30d)',
       CASE WHEN (SELECT count(DISTINCT amc_contract_id) FROM win_30) = 0
            THEN 'n/a'
            ELSE to_char(round(
              (SELECT count(*)::numeric FROM win_30)
              / nullif((SELECT count(DISTINCT amc_contract_id)::numeric FROM win_30), 0),
            2), 'FM990.00')
       END,
       CASE WHEN (SELECT count(DISTINCT amc_contract_id) FROM win_30) = 0
            THEN 0::numeric
            ELSE round(
              (SELECT count(*)::numeric FROM win_30)
              / nullif((SELECT count(DISTINCT amc_contract_id)::numeric FROM win_30), 0),
            2)
       END,
       'ratio'),

    ('Distinct contracts attempted (30d)',
       to_char((SELECT count(DISTINCT amc_contract_id) FROM win_30), 'FM999,999,999'),
       (SELECT count(DISTINCT amc_contract_id)::numeric FROM win_30),
       'volume'),

    ('Last attempt at',
       coalesce(to_char((SELECT ts FROM latest_attempt) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM latest_attempt)))::numeric, 0),
       'pulse'),

    ('Last success at',
       coalesce(to_char((SELECT ts FROM last_succ) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM last_succ)))::numeric, 0),
       'pulse'),

    ('Last failure at',
       coalesce(to_char((SELECT ts FROM last_fail) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM last_fail)))::numeric, 0),
       'pulse')
  ) AS t(metric, value_text, value_num, bucket);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_summary() TO authenticated;
COMMIT;