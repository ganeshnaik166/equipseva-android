BEGIN;
DROP FUNCTION IF EXISTS public.founder_bids_per_job_distribution();
CREATE OR REPLACE FUNCTION public.founder_bids_per_job_distribution()
RETURNS TABLE (
  bucket          text,
  bucket_order    int,
  cnt             bigint,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH bid_counts AS (
    SELECT
      j.id,
      coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b WHERE b.repair_job_id = j.id), 0) AS n_bids
    FROM public.repair_jobs j
    WHERE j.created_at >= now() - interval '90 days'
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN n_bids = 0 THEN '0 bids'
        WHEN n_bids = 1 THEN '1 bid'
        WHEN n_bids = 2 THEN '2 bids'
        WHEN n_bids BETWEEN 3 AND 5 THEN '3-5 bids'
        WHEN n_bids BETWEEN 6 AND 10 THEN '6-10 bids'
        ELSE '>10 bids'
      END                                  AS bucket,
      CASE
        WHEN n_bids = 0 THEN 1
        WHEN n_bids = 1 THEN 2
        WHEN n_bids = 2 THEN 3
        WHEN n_bids BETWEEN 3 AND 5 THEN 4
        WHEN n_bids BETWEEN 6 AND 10 THEN 5
        ELSE 6
      END                                  AS bucket_order
    FROM bid_counts
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
REVOKE EXECUTE ON FUNCTION public.founder_bids_per_job_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bids_per_job_distribution() TO authenticated;
COMMIT;
