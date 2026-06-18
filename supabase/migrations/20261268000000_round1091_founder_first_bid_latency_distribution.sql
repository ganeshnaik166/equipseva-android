BEGIN;
DROP FUNCTION IF EXISTS public.founder_first_bid_latency_distribution();
CREATE OR REPLACE FUNCTION public.founder_first_bid_latency_distribution()
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

  RETURN QUERY
  WITH first_bids AS (
    SELECT
      j.id AS job_id,
      extract(epoch from (min(b.created_at) - j.created_at)) / 60.0 AS minutes_to_first_bid
    FROM public.repair_jobs j
    JOIN public.repair_job_bids b ON b.repair_job_id = j.id
    WHERE j.created_at >= now() - interval '90 days'
    GROUP BY j.id, j.created_at
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN minutes_to_first_bid < 5      THEN '<5m'
        WHEN minutes_to_first_bid < 30     THEN '5-30m'
        WHEN minutes_to_first_bid < 120    THEN '30m-2h'
        WHEN minutes_to_first_bid < 1440   THEN '2-24h'
        WHEN minutes_to_first_bid < 4320   THEN '1-3d'
        ELSE '>3d'
      END                                  AS bucket,
      CASE
        WHEN minutes_to_first_bid < 5      THEN 1
        WHEN minutes_to_first_bid < 30     THEN 2
        WHEN minutes_to_first_bid < 120    THEN 3
        WHEN minutes_to_first_bid < 1440   THEN 4
        WHEN minutes_to_first_bid < 4320   THEN 5
        ELSE 6
      END                                  AS bucket_order
    FROM first_bids
  ),
  totals AS (
    SELECT count(*)::bigint AS total FROM bucketed
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                            AS cnt,
    CASE WHEN (SELECT total FROM totals) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / (SELECT total FROM totals), 1)
    END                                                          AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_first_bid_latency_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_first_bid_latency_distribution() TO authenticated;
COMMIT;
