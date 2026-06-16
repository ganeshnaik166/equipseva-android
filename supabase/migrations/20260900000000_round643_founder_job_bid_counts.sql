BEGIN;
DROP FUNCTION IF EXISTS public.founder_job_bid_counts();
CREATE OR REPLACE FUNCTION public.founder_job_bid_counts()
RETURNS TABLE (
  bucket  text,
  cnt     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH per_job AS (
    SELECT rj.id,
           (SELECT count(*)::int
              FROM public.repair_job_bids b
              WHERE b.repair_job_id = rj.id) AS bids
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '30 days'
  ),
  buckets(label, ord) AS (
    VALUES
      ('0 bids'::text,    1),
      ('1 bid'::text,     2),
      ('2-3 bids'::text,  3),
      ('4-5 bids'::text,  4),
      ('>5 bids'::text,   5)
  )
  SELECT b.label,
    coalesce(count(*) FILTER (
      WHERE (b.ord = 1 AND p.bids = 0)
         OR (b.ord = 2 AND p.bids = 1)
         OR (b.ord = 3 AND p.bids BETWEEN 2 AND 3)
         OR (b.ord = 4 AND p.bids BETWEEN 4 AND 5)
         OR (b.ord = 5 AND p.bids > 5)
    ), 0)::bigint
  FROM buckets b LEFT JOIN per_job p ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_job_bid_counts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_job_bid_counts() TO authenticated;
COMMIT;
