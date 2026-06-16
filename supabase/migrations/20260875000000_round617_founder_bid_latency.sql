BEGIN;
DROP FUNCTION IF EXISTS public.founder_bid_acceptance_latency();
CREATE OR REPLACE FUNCTION public.founder_bid_acceptance_latency()
RETURNS TABLE (
  window_label    text,
  jobs_with_accept bigint,
  avg_minutes     numeric,
  p50_minutes     numeric,
  p90_minutes     numeric,
  max_minutes     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH latencies AS (
    SELECT
      rj.created_at,
      extract(epoch FROM (b.created_at - rj.created_at)) / 60.0 AS minutes
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE b.created_at IS NOT NULL
      AND b.created_at >= rj.created_at
      AND rj.created_at >= now() - interval '90 days'
  ),
  w7 AS (SELECT * FROM latencies WHERE created_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM latencies WHERE created_at >= now() - interval '30 days'),
  w90 AS (SELECT * FROM latencies)
  SELECT '7d'::text,
         (SELECT count(*) FROM w7)::bigint,
         (SELECT round(avg(minutes)::numeric, 1) FROM w7),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w7),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w7),
         (SELECT round(max(minutes)::numeric, 1) FROM w7)
  UNION ALL
  SELECT '30d'::text,
         (SELECT count(*) FROM w30)::bigint,
         (SELECT round(avg(minutes)::numeric, 1) FROM w30),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w30),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w30),
         (SELECT round(max(minutes)::numeric, 1) FROM w30)
  UNION ALL
  SELECT '90d'::text,
         (SELECT count(*) FROM w90)::bigint,
         (SELECT round(avg(minutes)::numeric, 1) FROM w90),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w90),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY minutes)::numeric, 1) FROM w90),
         (SELECT round(max(minutes)::numeric, 1) FROM w90);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bid_acceptance_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bid_acceptance_latency() TO authenticated;
COMMIT;
