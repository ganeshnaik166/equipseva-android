BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_recency();
CREATE OR REPLACE FUNCTION public.founder_engineer_recency()
RETURNS TABLE (
  bucket      text,
  cnt         bigint,
  share_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.engineers e WHERE e.verification_status = 'verified';
  RETURN QUERY
  WITH last_bid AS (
    SELECT
      e.user_id,
      coalesce((SELECT max(b.created_at) FROM public.repair_job_bids b WHERE b.engineer_user_id = e.user_id), e.created_at) AS last_at
    FROM public.engineers e
    WHERE e.verification_status = 'verified'
  ),
  recency AS (
    SELECT extract(epoch FROM (now() - last_at)) / 86400.0 AS days_old FROM last_bid
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('Active (≤7d)'::text,   1, 0::numeric,   7::numeric),
      ('7-30d',                 2, 7::numeric,  30::numeric),
      ('30-60d',                3, 30::numeric, 60::numeric),
      ('60-90d',                4, 60::numeric, 90::numeric),
      ('Dormant (>90d)',        5, 90::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE r.days_old >= b.lo AND r.days_old < b.hi)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE r.days_old >= b.lo AND r.days_old < b.hi)::numeric
           / v_total::numeric * 100.0, 1)
    END
  FROM buckets b LEFT JOIN recency r ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_recency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_recency() TO authenticated;
COMMIT;
