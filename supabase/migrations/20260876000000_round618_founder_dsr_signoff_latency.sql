BEGIN;
DROP FUNCTION IF EXISTS public.founder_dsr_signoff_latency();
CREATE OR REPLACE FUNCTION public.founder_dsr_signoff_latency()
RETURNS TABLE (
  window_label    text,
  signed_count    bigint,
  avg_hours       numeric,
  p50_hours       numeric,
  p90_hours       numeric,
  unsigned_count  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH lat AS (
    SELECT
      d.created_at,
      extract(epoch FROM (d.updated_at - d.created_at)) / 3600.0 AS hours
    FROM public.dsr_reports d
    WHERE d.status = 'signed'
      AND d.created_at >= now() - interval '90 days'
      AND d.updated_at IS NOT NULL
      AND d.updated_at >= d.created_at
  ),
  w7 AS (SELECT * FROM lat WHERE created_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM lat WHERE created_at >= now() - interval '30 days'),
  w90 AS (SELECT * FROM lat),
  unsigned AS (
    SELECT
      CASE
        WHEN d.created_at >= now() - interval '7 days'  THEN '7d'
        WHEN d.created_at >= now() - interval '30 days' THEN '30d'
        ELSE '90d'
      END AS w
    FROM public.dsr_reports d
    WHERE d.status = 'pending_hospital_sign'
      AND d.created_at >= now() - interval '90 days'
  )
  SELECT '7d'::text,
         (SELECT count(*) FROM w7)::bigint,
         (SELECT round(avg(hours)::numeric, 1) FROM w7),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w7),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w7),
         (SELECT count(*) FROM unsigned WHERE w = '7d')::bigint
  UNION ALL
  SELECT '30d',
         (SELECT count(*) FROM w30)::bigint,
         (SELECT round(avg(hours)::numeric, 1) FROM w30),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w30),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w30),
         (SELECT count(*) FROM unsigned WHERE w IN ('7d','30d'))::bigint
  UNION ALL
  SELECT '90d',
         (SELECT count(*) FROM w90)::bigint,
         (SELECT round(avg(hours)::numeric, 1) FROM w90),
         (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w90),
         (SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM w90),
         (SELECT count(*) FROM unsigned)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dsr_signoff_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dsr_signoff_latency() TO authenticated;
COMMIT;
