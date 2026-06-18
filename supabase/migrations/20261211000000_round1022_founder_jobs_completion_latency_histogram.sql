BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_completion_latency_histogram();
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_latency_histogram()
RETURNS TABLE (
  bucket          text,
  bucket_order    int,
  cnt             bigint,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_tot
  FROM public.repair_jobs j
  WHERE j.status = 'completed'
    AND j.completed_at IS NOT NULL
    AND j.completed_at >= now() - interval '90 days';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT
      extract(epoch from (j.completed_at - j.created_at)) / 3600.0 AS h
    FROM public.repair_jobs j
    WHERE j.status = 'completed'
      AND j.completed_at IS NOT NULL
      AND j.completed_at >= now() - interval '90 days'
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN h < 4   THEN '<4h'
        WHEN h < 24  THEN '4-24h'
        WHEN h < 72  THEN '1-3d'
        WHEN h < 168 THEN '3-7d'
        WHEN h < 336 THEN '7-14d'
        WHEN h < 720 THEN '14-30d'
        ELSE '>30d'
      END                                AS bucket,
      CASE
        WHEN h < 4   THEN 1
        WHEN h < 24  THEN 2
        WHEN h < 72  THEN 3
        WHEN h < 168 THEN 4
        WHEN h < 336 THEN 5
        WHEN h < 720 THEN 6
        ELSE 7
      END                                AS bucket_order
    FROM agg
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                  AS cnt,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END  AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_completion_latency_histogram() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_completion_latency_histogram() TO authenticated;
COMMIT;
