BEGIN;
DROP FUNCTION IF EXISTS public.founder_first_bid_latency();
CREATE OR REPLACE FUNCTION public.founder_first_bid_latency()
RETURNS TABLE (
  bucket    text,
  cnt       bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH first_bid AS (
    SELECT
      rj.id,
      rj.created_at AS posted_at,
      (SELECT min(b.created_at) FROM public.repair_job_bids b WHERE b.repair_job_id = rj.id) AS first_bid_at
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
  ),
  with_delta AS (
    SELECT
      extract(epoch FROM (first_bid_at - posted_at)) / 60.0 AS delta_min
    FROM first_bid
    WHERE first_bid_at IS NOT NULL
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 5 min'::text,  1, 0::numeric,    5::numeric),
      ('5-30 min',       2, 5::numeric,   30::numeric),
      ('30 min-2h',      3, 30::numeric, 120::numeric),
      ('2-12h',          4, 120::numeric, 720::numeric),
      ('12-48h',         5, 720::numeric, 2880::numeric),
      ('> 48h',          6, 2880::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE wd.delta_min >= b.lo AND wd.delta_min < b.hi)::bigint,
    CASE WHEN (SELECT count(*) FROM with_delta) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE wd.delta_min >= b.lo AND wd.delta_min < b.hi)::numeric
           / (SELECT count(*) FROM with_delta)::numeric * 100.0, 1)
    END
  FROM buckets b LEFT JOIN with_delta wd ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_first_bid_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_first_bid_latency() TO authenticated;
COMMIT;
