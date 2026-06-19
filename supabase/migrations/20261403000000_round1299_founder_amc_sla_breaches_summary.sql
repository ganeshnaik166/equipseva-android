BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_sla_breaches_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_sla_breaches_summary()
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
  all_b AS (
    SELECT * FROM public.amc_sla_breaches
  ),
  win_90 AS (
    SELECT * FROM public.amc_sla_breaches
    WHERE detected_at >= now() - interval '90 days'
  ),
  win_30 AS (
    SELECT * FROM public.amc_sla_breaches
    WHERE detected_at >= now() - interval '30 days'
  ),
  win_7 AS (
    SELECT * FROM public.amc_sla_breaches
    WHERE detected_at >= now() - interval '7 days'
  ),
  win_24 AS (
    SELECT * FROM public.amc_sla_breaches
    WHERE detected_at >= now() - interval '24 hours'
  ),
  open_b AS (
    SELECT * FROM public.amc_sla_breaches WHERE resolved_at IS NULL
  ),
  stale_open AS (
    SELECT * FROM public.amc_sla_breaches
    WHERE resolved_at IS NULL
      AND detected_at < now() - interval '7 days'
  ),
  repeat_contracts AS (
    -- Contracts with >=3 breaches in the last 90d = retention risk
    SELECT amc_contract_id
    FROM public.amc_sla_breaches
    WHERE detected_at >= now() - interval '90 days'
    GROUP BY amc_contract_id
    HAVING count(*) >= 3
  ),
  by_tier_30 AS (
    SELECT c.amc_tier AS tier, count(*) AS n
    FROM public.amc_sla_breaches b
    JOIN public.amc_contracts c ON c.id = b.amc_contract_id
    WHERE b.detected_at >= now() - interval '30 days'
    GROUP BY c.amc_tier
  ),
  by_engineer_30 AS (
    SELECT e.user_id AS eng_user, count(*) AS n
    FROM public.amc_sla_breaches b
    JOIN public.repair_jobs rj ON rj.id = b.visit_id
    JOIN public.engineers e ON e.id = rj.engineer_id
    WHERE b.detected_at >= now() - interval '30 days'
    GROUP BY e.user_id
  ),
  latest_b AS (
    SELECT max(detected_at) AS ts FROM public.amc_sla_breaches
  ),
  latest_resolved AS (
    SELECT max(resolved_at) AS ts FROM public.amc_sla_breaches WHERE resolved_at IS NOT NULL
  )
  SELECT * FROM (VALUES
    ('Total breaches (all-time)',
       to_char((SELECT count(*) FROM all_b), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_b),
       'volume'),

    ('Breaches (last 90d)',
       to_char((SELECT count(*) FROM win_90), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_90),
       'volume'),

    ('Breaches (last 30d)',
       to_char((SELECT count(*) FROM win_30), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30),
       'volume'),

    ('Breaches (last 7d)',
       to_char((SELECT count(*) FROM win_7), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_7),
       'volume'),

    ('Breaches (last 24h)',
       to_char((SELECT count(*) FROM win_24), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_24),
       'volume'),

    ('Response-time breaches (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE breach_type='response_time'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE breach_type='response_time'),
       'breach_type'),

    ('No-show breaches (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE breach_type='no_show'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE breach_type='no_show'),
       'breach_type'),

    ('Quality breaches (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE breach_type='quality'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE breach_type='quality'),
       'breach_type'),

    ('Emergency-severity breaches (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE severity='emergency'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE severity='emergency'),
       'breach_type'),

    ('Open breaches (unresolved)',
       to_char((SELECT count(*) FROM open_b), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM open_b),
       'risk'),

    ('Stale open (>7d unresolved)',
       to_char((SELECT count(*) FROM stale_open), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM stale_open),
       'risk'),

    ('Repeat-offender contracts (>=3 in 90d)',
       to_char((SELECT count(*) FROM repeat_contracts), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM repeat_contracts),
       'risk'),

    ('Distinct contracts breached (30d)',
       to_char((SELECT count(DISTINCT amc_contract_id) FROM win_30), 'FM999,999,999'),
       (SELECT count(DISTINCT amc_contract_id)::numeric FROM win_30),
       'volume'),

    ('Credit issued (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(credit_issued_rupees) FROM win_30),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(credit_issued_rupees)::numeric FROM win_30),0),
       'money'),

    ('Credit issued (90d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(credit_issued_rupees) FROM win_90),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(credit_issued_rupees)::numeric FROM win_90),0),
       'money'),

    ('Credit issued (all-time, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(credit_issued_rupees) FROM all_b),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(credit_issued_rupees)::numeric FROM all_b),0),
       'money'),

    ('Avg breach overshoot hours (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE actual_hours IS NOT NULL) = 0
            THEN 'n/a'
            ELSE to_char(round(
              (SELECT avg(actual_hours - expected_within_hours) FROM win_30 WHERE actual_hours IS NOT NULL),
            2), 'FM990.00') || ' h'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE actual_hours IS NOT NULL) = 0
            THEN 0::numeric
            ELSE round(
              (SELECT avg(actual_hours - expected_within_hours) FROM win_30 WHERE actual_hours IS NOT NULL),
            2)
       END,
       'ratio'),

    ('Resolved share (90d)',
       CASE WHEN (SELECT count(*) FROM win_90) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_90 WHERE resolved_at IS NOT NULL)
              / nullif((SELECT count(*)::numeric FROM win_90), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_90) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_90 WHERE resolved_at IS NOT NULL)
              / nullif((SELECT count(*)::numeric FROM win_90), 0),
            1)
       END,
       'rate'),

    ('Top tier by breaches (30d)',
       coalesce((SELECT tier || ' (' || n || ')' FROM by_tier_30 ORDER BY n DESC LIMIT 1), 'n/a'),
       coalesce((SELECT n::numeric FROM by_tier_30 ORDER BY n DESC LIMIT 1), 0),
       'breach_type'),

    ('Top engineer by breaches (30d)',
       coalesce((SELECT substr(eng_user::text,1,8) || ' (' || n || ')' FROM by_engineer_30 ORDER BY n DESC LIMIT 1), 'n/a'),
       coalesce((SELECT n::numeric FROM by_engineer_30 ORDER BY n DESC LIMIT 1), 0),
       'risk'),

    ('Last breach at',
       coalesce(to_char((SELECT ts FROM latest_b) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM latest_b)))::numeric, 0),
       'pulse'),

    ('Last resolved at',
       coalesce(to_char((SELECT ts FROM latest_resolved) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM latest_resolved)))::numeric, 0),
       'pulse')
  ) AS t(metric, value_text, value_num, bucket);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_sla_breaches_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_sla_breaches_summary() TO authenticated;
COMMIT;
