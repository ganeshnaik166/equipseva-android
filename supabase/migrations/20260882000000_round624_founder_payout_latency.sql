BEGIN;
DROP FUNCTION IF EXISTS public.founder_payout_settlement_latency();
CREATE OR REPLACE FUNCTION public.founder_payout_settlement_latency()
RETURNS TABLE (
  window_label    text,
  paid_count      bigint,
  avg_hours       numeric,
  p50_hours       numeric,
  p90_hours       numeric,
  pending_count   bigint,
  failed_count    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paid AS (
    SELECT
      queued_at,
      extract(epoch FROM (processed_at - queued_at)) / 3600.0 AS hours
    FROM public.engineer_payouts
    WHERE status IN ('paid','processed','completed')
      AND queued_at >= now() - interval '90 days'
      AND processed_at IS NOT NULL
      AND processed_at >= queued_at
  ),
  w7  AS (SELECT * FROM paid WHERE queued_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM paid WHERE queued_at >= now() - interval '30 days'),
  w90 AS (SELECT * FROM paid),
  pending AS (
    SELECT
      CASE
        WHEN queued_at >= now() - interval '7 days'  THEN '7d'
        WHEN queued_at >= now() - interval '30 days' THEN '30d'
        ELSE '90d'
      END AS w
    FROM public.engineer_payouts
    WHERE status IN ('queued','pending')
      AND queued_at >= now() - interval '90 days'
  ),
  failed AS (
    SELECT
      CASE
        WHEN queued_at >= now() - interval '7 days'  THEN '7d'
        WHEN queued_at >= now() - interval '30 days' THEN '30d'
        ELSE '90d'
      END AS w
    FROM public.engineer_payouts
    WHERE status IN ('failed','cancelled')
      AND queued_at >= now() - interval '90 days'
  )
  SELECT '7d'::text,
    (SELECT count(*) FROM w7)::bigint,
    (SELECT round(avg(hours)::numeric, 1) FROM w7),
    (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w7),
    (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w7),
    (SELECT count(*) FROM pending WHERE w = '7d')::bigint,
    (SELECT count(*) FROM failed WHERE w = '7d')::bigint
  UNION ALL
  SELECT '30d',
    (SELECT count(*) FROM w30)::bigint,
    (SELECT round(avg(hours)::numeric, 1) FROM w30),
    (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w30),
    (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w30),
    (SELECT count(*) FROM pending WHERE w IN ('7d','30d'))::bigint,
    (SELECT count(*) FROM failed WHERE w IN ('7d','30d'))::bigint
  UNION ALL
  SELECT '90d',
    (SELECT count(*) FROM w90)::bigint,
    (SELECT round(avg(hours)::numeric, 1) FROM w90),
    (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w90),
    (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w90),
    (SELECT count(*) FROM pending)::bigint,
    (SELECT count(*) FROM failed)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_settlement_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_settlement_latency() TO authenticated;
COMMIT;
