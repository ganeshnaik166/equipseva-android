BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_subscription_charges_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_subscription_charges_summary()
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
  all_c AS (
    SELECT * FROM public.amc_subscription_charges
  ),
  win_30 AS (
    SELECT * FROM public.amc_subscription_charges
    WHERE attempted_at >= now() - interval '30 days'
  ),
  win_7 AS (
    SELECT * FROM public.amc_subscription_charges
    WHERE attempted_at >= now() - interval '7 days'
  ),
  win_24 AS (
    SELECT * FROM public.amc_subscription_charges
    WHERE attempted_at >= now() - interval '24 hours'
  ),
  stuck_attempted AS (
    -- 'attempted' state lingering > 24h = worker did not transition
    SELECT * FROM public.amc_subscription_charges
    WHERE status = 'attempted'
      AND attempted_at < now() - interval '24 hours'
  ),
  multi_fail AS (
    -- Subscriptions with >= 2 failed charges (auto-debit reliability risk)
    SELECT subscription_id
    FROM public.amc_subscription_charges
    WHERE status = 'failed'
    GROUP BY subscription_id
    HAVING count(*) >= 2
  ),
  latest_attempt AS (
    SELECT max(attempted_at) AS ts FROM public.amc_subscription_charges
  ),
  last_succ AS (
    SELECT max(settled_at) AS ts FROM public.amc_subscription_charges WHERE status = 'succeeded'
  ),
  last_fail AS (
    SELECT max(settled_at) AS ts FROM public.amc_subscription_charges WHERE status = 'failed'
  ),
  last_refund AS (
    SELECT max(settled_at) AS ts FROM public.amc_subscription_charges WHERE status = 'refunded'
  )
  SELECT * FROM (VALUES
    ('Total charges (all-time)',
       to_char((SELECT count(*) FROM all_c), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_c),
       'volume'),

    ('Charges (last 30d)',
       to_char((SELECT count(*) FROM win_30), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30),
       'volume'),

    ('Charges (last 7d)',
       to_char((SELECT count(*) FROM win_7), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_7),
       'volume'),

    ('Charges (last 24h)',
       to_char((SELECT count(*) FROM win_24), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_24),
       'volume'),

    ('Distinct subscriptions charged (30d)',
       to_char((SELECT count(DISTINCT subscription_id) FROM win_30), 'FM999,999,999'),
       (SELECT count(DISTINCT subscription_id)::numeric FROM win_30),
       'volume'),

    ('Succeeded (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='succeeded'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded'),
       'outcome'),

    ('Failed (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='failed'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='failed'),
       'outcome'),

    ('Refunded (30d)',
       to_char((SELECT count(*) FROM win_30 WHERE status='refunded'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM win_30 WHERE status='refunded'),
       'outcome'),

    ('Attempted (open, all-time)',
       to_char((SELECT count(*) FROM all_c WHERE status='attempted'), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_c WHERE status='attempted'),
       'outcome'),

    ('Success rate (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='succeeded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1)
       END,
       'rate'),

    ('Failure rate (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='failed')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='failed')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1)
       END,
       'rate'),

    ('Refund rate (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 'n/a'
            ELSE to_char(round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='refunded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1), 'FM990.0') || '%'
       END,
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status IN ('succeeded','failed','refunded')) = 0
            THEN 0::numeric
            ELSE round(
              100.0 * (SELECT count(*)::numeric FROM win_30 WHERE status='refunded')
              / nullif((SELECT count(*)::numeric FROM win_30 WHERE status IN ('succeeded','failed','refunded')), 0),
            1)
       END,
       'rate'),

    ('Stuck attempted (>24h)',
       to_char((SELECT count(*) FROM stuck_attempted), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM stuck_attempted),
       'risk'),

    ('Repeat-fail subscriptions (>=2 fails)',
       to_char((SELECT count(*) FROM multi_fail), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM multi_fail),
       'risk'),

    ('Pool-orphan succeeded (no ledger link)',
       to_char((SELECT count(*) FROM all_c WHERE status='succeeded' AND pool_ledger_id IS NULL), 'FM999,999,999'),
       (SELECT count(*)::numeric FROM all_c WHERE status='succeeded' AND pool_ledger_id IS NULL),
       'risk'),

    ('Revenue captured (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(amount_rupees) FROM win_30 WHERE status='succeeded'),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(amount_rupees)::numeric FROM win_30 WHERE status='succeeded'),0),
       'money'),

    ('Revenue at-risk failed (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(amount_rupees) FROM win_30 WHERE status='failed'),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(amount_rupees)::numeric FROM win_30 WHERE status='failed'),0),
       'money'),

    ('Revenue refunded (30d, rupees)',
       'INR ' || to_char(coalesce((SELECT sum(amount_rupees) FROM win_30 WHERE status='refunded'),0), 'FM999,999,999.00'),
       coalesce((SELECT sum(amount_rupees)::numeric FROM win_30 WHERE status='refunded'),0),
       'money'),

    ('Avg charge amount succeeded (30d)',
       CASE WHEN (SELECT count(*) FROM win_30 WHERE status='succeeded') = 0
            THEN 'n/a'
            ELSE 'INR ' || to_char(round(
              (SELECT avg(amount_rupees) FROM win_30 WHERE status='succeeded')
            , 2), 'FM999,999,999.00')
       END,
       coalesce((SELECT round(avg(amount_rupees), 2) FROM win_30 WHERE status='succeeded'), 0),
       'ratio'),

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
       'pulse'),

    ('Last refund at',
       coalesce(to_char((SELECT ts FROM last_refund) AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') || ' IST', 'n/a'),
       coalesce(extract(epoch FROM (now() - (SELECT ts FROM last_refund)))::numeric, 0),
       'pulse')
  ) AS t(metric, value_text, value_num, bucket);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_subscription_charges_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_subscription_charges_summary() TO authenticated;
COMMIT;
